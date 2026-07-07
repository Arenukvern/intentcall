import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;

import 'catalog/catalog_loader.dart';
import 'commands/apple_app_intents_testing.dart';
import 'config/host_profiles.dart';
import 'config/intentcall_config.dart';
import 'mcp/stdio_mcp_server.dart';
import 'utils/cli_utils.dart';

/// Framework-neutral IntentCall CLI entry point.
final class IntentCallCommandRunner extends CommandRunner<int> {
  IntentCallCommandRunner()
    : super(
        'intentcall',
        'Framework-neutral IntentCall CLI for manifest export and platform sync.',
      ) {
    addCommand(_DoctorCommand());
    addCommand(_ConfigCommand());
    addCommand(_ManifestCommand());
    addCommand(_PlatformCommand());
    addCommand(_CodegenCommand());
    addCommand(_McpCommand());
    addCommand(_AppleAppIntentsTestingCommand());
  }
}

// ignore: avoid_classes_with_only_static_members
final class _ProjectDirOption {
  static void add(final ArgParser parser) {
    parser.addOption(
      'project-dir',
      help: 'Project root directory.',
      defaultsTo: defaultProjectDir(),
    );
  }

  static String read(final ArgResults results) {
    final value = results['project-dir'];
    if (value != null) {
      return p.normalize(p.absolute('$value'));
    }
    return defaultProjectDir();
  }
}

final class _DoctorCommand extends Command<int> {
  @override
  String get name => 'doctor';

  @override
  String get description => 'Check developer environment health.';

  @override
  Future<int> run() =>
      _runDoctor(asJson: argResults!['json'] as bool? ?? false);

  @override
  ArgParser get argParser => ArgParser()..addFlag('json', negatable: false);

  Future<int> _runDoctor({required final bool asJson}) async {
    final checks = <Map<String, Object?>>[];
    var healthy = true;

    Future<void> checkTool(
      final String id,
      final List<String> command, {
      final bool required = true,
    }) async {
      try {
        final result = await Process.run(command.first, command.sublist(1));
        final ok = result.exitCode == 0;
        if (!ok && required) {
          healthy = false;
        }
        checks.add(<String, Object?>{
          'id': id,
          'ok': ok,
          'required': required,
          'detail': '${result.stdout}${result.stderr}'.trim(),
        });
      } catch (error) {
        if (required) {
          healthy = false;
        }
        checks.add(<String, Object?>{
          'id': id,
          'ok': false,
          'required': required,
          'detail': '$error',
        });
      }
    }

    await checkTool('dart', <String>['dart', '--version']);
    await checkTool('flutter', <String>[
      'flutter',
      '--version',
    ], required: false);
    await checkTool('just', <String>['just', '--version'], required: false);

    final lockExists = File('pubspec.lock').existsSync();
    if (!lockExists) {
      healthy = false;
    }
    checks.add(<String, Object?>{
      'id': 'pubspec.lock',
      'ok': lockExists,
      'required': true,
      'detail': lockExists ? 'present' : 'missing — run dart pub get',
    });

    if (asJson) {
      printJson(<String, Object?>{'healthy': healthy, 'checks': checks});
    } else {
      stdout.writeln('== IntentCall Doctor ==');
      for (final check in checks) {
        final mark = (check['ok']! as bool) ? '✓' : '✗';
        stdout.writeln('$mark ${check['id']}: ${check['detail']}');
      }
      stdout.writeln('\nStatus: ${healthy ? 'HEALTHY' : 'UNHEALTHY'}');
    }
    return healthy ? 0 : 1;
  }
}

final class _ConfigCommand extends Command<int> {
  _ConfigCommand() {
    addSubcommand(_ConfigShowCommand());
  }

  @override
  String get name => 'config';

  @override
  String get description => 'Show intentcall.yaml host wiring.';
}

final class _ConfigShowCommand extends Command<int> {
  @override
  String get name => 'show';

  @override
  String get description => 'Print parsed intentcall.yaml.';

  @override
  int run() => _runShow(argResults!);

  int _runShow(final ArgResults results) {
    final projectRoot = _ProjectDirOption.read(results);
    final config = loadIntentCallConfig(projectRoot);
    if (config == null) {
      printUsageError('intentcall.yaml not found under $projectRoot');
      return inputMissingExitCode();
    }
    final enriched = Map<String, Object?>.from(config.toJson())
      ..['resolvedPlatforms'] = resolveEnabledPlatforms(config);
    if (results['json'] as bool? ?? false) {
      printJson(enriched);
    } else {
      stdout
        ..writeln('# intentcall.yaml (${config.sourcePath})')
        ..writeln(encodePrettyJson(enriched));
    }
    return 0;
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser.addFlag('json', negatable: false);
    return parser;
  }
}

final class _ManifestCommand extends Command<int> {
  _ManifestCommand() {
    addSubcommand(_ManifestValidateCommand());
    addSubcommand(_ManifestExportCommand());
  }

  @override
  String get name => 'manifest';

  @override
  String get description => 'Validate and export agent_manifest.json.';
}

final class _ManifestValidateCommand extends Command<int> {
  @override
  String get name => 'validate';

  @override
  String get description => 'Parse and validate agent_manifest.json.';

  @override
  int run() {
    final results = argResults!;
    final projectRoot = _ProjectDirOption.read(results);
    final config = loadIntentCallConfig(projectRoot);
    final manifestPath = results['manifest'] == null
        ? resolveManifestOutput(projectRoot, config: config)
        : resolveProjectPath(projectRoot, '${results['manifest']}');

    if (!manifestPath.existsSync()) {
      printUsageError('manifest not found: ${manifestPath.path}');
      return inputMissingExitCode();
    }

    try {
      final manifest = AgentManifest.parse(manifestPath.readAsStringSync());
      if (results['json'] as bool? ?? false) {
        printJson(<String, Object?>{
          'ok': true,
          'path': manifestPath.path,
          'toolCount': manifest.tools.length,
          'entityTypeCount': manifest.entityTypes.length,
        });
      } else {
        stdout
          ..writeln('OK: valid manifest at ${manifestPath.path}')
          ..writeln(
            '  tools=${manifest.tools.length} entityTypes=${manifest.entityTypes.length}',
          );
      }
      return 0;
    } on FormatException catch (error) {
      printUsageError('invalid manifest: ${error.message}');
      return dataErrorExitCode();
    }
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser
      ..addOption('manifest', help: 'Path to agent_manifest.json.')
      ..addFlag('json', negatable: false);
    return parser;
  }
}

final class _ManifestExportCommand extends Command<int> {
  @override
  String get name => 'export';

  @override
  String get description =>
      'Merge catalog + projection into agent_manifest.json.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final projectRoot = _ProjectDirOption.read(results);
    final config = loadIntentCallConfig(projectRoot);
    final outPath = results['out'] == null
        ? resolveManifestOutput(projectRoot, config: config)
        : resolveProjectPath(projectRoot, '${results['out']}');
    final checkOnly = results['check'] as bool? ?? false;

    const exporter = ManifestExporter();
    final context = exporter.loadExportContext(projectRoot: projectRoot);
    const catalogLoader = CatalogLoader();
    final catalog = await catalogLoader.load(projectRoot: projectRoot);
    final entityTypeDescriptors = await catalogLoader.loadEntityTypeDescriptors(
      projectRoot: projectRoot,
    );

    final encoded = exporter.encodeManifest(
      exporter.buildManifest(
        catalog: catalog,
        context: context,
        entityTypeDescriptors: entityTypeDescriptors,
      ),
    );

    if (checkOnly) {
      if (!outPath.existsSync()) {
        printUsageError('manifest missing at ${outPath.path}');
        return inputMissingExitCode();
      }
      final current = outPath.readAsStringSync();
      if (current == encoded) {
        stdout.writeln('OK: manifest is fresh (${outPath.path})');
        return 0;
      }
      printUsageError(
        'manifest drift at ${outPath.path} — run intentcall manifest export',
      );
      return 1;
    }

    outPath.parent.createSync(recursive: true);
    outPath.writeAsStringSync(encoded);
    stdout.writeln('OK: wrote manifest to ${outPath.path}');
    return 0;
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser
      ..addFlag('check', negatable: false, help: 'Verify manifest freshness.')
      ..addOption('out', help: 'Output manifest path.')
      ..addFlag('json', negatable: false);
    return parser;
  }
}

final class _PlatformCommand extends Command<int> {
  _PlatformCommand() {
    addSubcommand(_PlatformSyncCommand());
    addSubcommand(_PlatformHooksCommand());
  }

  @override
  String get name => 'platform';

  @override
  String get description =>
      'Sync native/web artifacts from agent_manifest.json.';
}

final class _PlatformSyncCommand extends Command<int> {
  @override
  String get name => 'sync';

  @override
  String get description => 'Emit platform artifacts from agent_manifest.json.';

  @override
  int run() => runPlatformSync(argResults!);

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser
      ..addMultiOption(
        'platform',
        abbr: 'p',
        help: 'Platform target(s): web, android, ios, macos, linux, windows.',
        valueHelp: 'LIST',
      )
      ..addFlag('check', negatable: false, help: 'Verify artifact freshness.')
      ..addFlag('dry-run', negatable: false, help: 'Report changes only.')
      ..addOption('host', help: 'Host profile hint (flutter|jaspr).');
    return parser;
  }
}

int runPlatformSync(final ArgResults results) {
  final projectRoot = _ProjectDirOption.read(results);
  final config = loadIntentCallConfig(projectRoot);
  final platforms = parsePlatformList(results['platform'] as List<String>);
  final resolved = platforms.isEmpty
      ? resolveEnabledPlatforms(
          config ?? const IntentCallConfig(host: IntentCallHost.flutter),
        )
      : platforms;

  if (resolved.isEmpty) {
    printUsageError(
      '--platform is required when intentcall.yaml has no defaults.',
    );
    return usageExitCode();
  }

  const sync = PlatformSync();
  final checkOnly = results['check'] as bool? ?? false;
  final dryRun = results['dry-run'] as bool? ?? false;

  try {
    if (checkOnly) {
      final ok = sync.checkPlatforms(projectRoot, resolved);
      if (ok) {
        stdout.writeln('OK: platform artifacts are fresh ($resolved)');
        return 0;
      }
      printUsageError(
        'platform artifact drift for $resolved — run intentcall platform sync',
      );
      return 1;
    }

    final result = sync.syncPlatforms(
      projectRoot: projectRoot,
      platforms: resolved,
      dryRun: dryRun,
    );
    if (dryRun) {
      stdout.writeln(
        'Dry run: ${result.artifacts.where((final a) => a.changed).length} '
        'artifact(s) would change.',
      );
    } else {
      stdout.writeln('OK: synced platforms $resolved');
    }
    return 0;
  } on ArgumentError catch (error) {
    printUsageError('$error');
    return usageExitCode();
  } on StateError catch (error) {
    printUsageError('$error');
    return dataErrorExitCode();
  }
}

final class _PlatformHooksCommand extends Command<int> {
  _PlatformHooksCommand() {
    addSubcommand(_PlatformHooksInitCommand());
    addSubcommand(_PlatformHooksPrintCommand());
  }

  @override
  String get name => 'hooks';

  @override
  String get description => 'Initialize or print platform hook templates.';
}

final class _PlatformHooksInitCommand extends Command<int> {
  @override
  String get name => 'init';

  @override
  String get description => 'Patch Flutter/Jaspr hook files once.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final projectRoot = _ProjectDirOption.read(results);
    final host = normalizeHostName('${results['host']}');
    final checkOnly = results['check'] as bool? ?? false;

    if (host == IntentCallHost.jaspr.name) {
      return _initJasprHooks(projectRoot: projectRoot, checkOnly: checkOnly);
    }

    final report = await const PlatformHooksInit().run(
      projectRoot: projectRoot,
      checkOnly: checkOnly,
    );
    for (final target in report.targets) {
      final mark = target.ok ? 'OK' : 'FAIL';
      stdout.writeln('$mark ${target.id}: ${target.path}');
      if (target.message != null) {
        stdout.writeln('  ${target.message}');
      }
    }
    return report.ok ? 0 : 1;
  }

  Future<int> _initJasprHooks({
    required final String projectRoot,
    required final bool checkOnly,
  }) async {
    final hookFile = File(
      p.join(projectRoot, '.intentcall', 'web_build_hook.sh'),
    );
    final expected = '${kJasprWebCodegenHook.trim()}\n';
    final exists = hookFile.existsSync();
    final current = exists ? hookFile.readAsStringSync() : '';
    final ok = exists && current.contains('intentcall-platform: begin');

    if (checkOnly) {
      if (ok) {
        stdout.writeln('OK: Jaspr web hook present (${hookFile.path})');
        return 0;
      }
      printUsageError('missing Jaspr web hook at ${hookFile.path}');
      return 1;
    }

    if (!ok) {
      hookFile.parent.createSync(recursive: true);
      hookFile.writeAsStringSync(expected);
      stdout.writeln('OK: wrote Jaspr web hook to ${hookFile.path}');
    } else {
      stdout.writeln('OK: Jaspr web hook already present');
    }
    return 0;
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser
      ..addOption(
        'host',
        help: 'Host profile: flutter or jaspr.',
        defaultsTo: 'flutter',
        allowed: <String>['flutter', 'jaspr'],
      )
      ..addFlag('check', negatable: false);
    return parser;
  }
}

final class _PlatformHooksPrintCommand extends Command<int> {
  @override
  String get name => 'print';

  @override
  String get description => 'Print hook template snippets.';

  @override
  int run() {
    final results = argResults!;
    final host = normalizeHostName('${results['host']}');
    final platform = '${results['platform'] ?? ''}'.trim().toLowerCase();

    final snippets = <String, String>{
      'android': kAndroidGradleCodegenHook,
      'ios': kAppleXcodeCodegenRunScript,
      'macos': kAppleXcodeCodegenRunScript,
      'jaspr': kJasprWebCodegenHook,
      'web': kJasprWebCodegenHook,
    };

    if (platform.isNotEmpty) {
      final snippet = snippets[platform];
      if (snippet == null) {
        printUsageError('unknown platform "$platform" for hook print.');
        return usageExitCode();
      }
      stdout.writeln(snippet.trim());
      return 0;
    }

    final keys = host == IntentCallHost.jaspr.name
        ? <String>['jaspr', 'web']
        : <String>['android', 'ios', 'macos'];
    for (final key in keys) {
      stdout
        ..writeln('== $key ==')
        ..writeln(snippets[key]!.trim())
        ..writeln();
    }
    return 0;
  }

  @override
  ArgParser get argParser => ArgParser()
    ..addOption('host', defaultsTo: 'flutter')
    ..addOption('platform', help: 'Print one platform snippet.');
}

final class _CodegenCommand extends Command<int> {
  _CodegenCommand() {
    addSubcommand(_CodegenSyncCommand());
  }

  @override
  String get name => 'codegen';

  @override
  String get description => 'Alias for platform sync.';
}

final class _CodegenSyncCommand extends Command<int> {
  @override
  String get name => 'sync';

  @override
  String get description => 'Alias of platform sync.';

  @override
  int run() => runPlatformSync(argResults!);

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser
      ..addMultiOption('platform', abbr: 'p')
      ..addFlag('check', negatable: false)
      ..addFlag('dry-run', negatable: false)
      ..addOption('host');
    return parser;
  }
}

final class _McpCommand extends Command<int> {
  _McpCommand() {
    addSubcommand(_McpServeCommand());
  }

  @override
  String get name => 'mcp';

  @override
  String get description => 'Run IntentCall MCP transports.';
}

final class _McpServeCommand extends Command<int> {
  @override
  String get name => 'serve';

  @override
  String get description => 'Start stdio MCP server (dogfood).';

  @override
  Future<int> run() async {
    final results = argResults!;
    final entrypoint = '${results['entrypoint'] ?? ''}'.trim();
    if (entrypoint.isNotEmpty) {
      stderr.writeln(
        'Note: dynamic --entrypoint loading is not implemented yet; '
        'starting empty registry host.',
      );
    }
    await runIntentCallStdioMcpServer();
    return 0;
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    parser.addOption(
      'entrypoint',
      help: 'Optional Dart entrypoint with AgentModule registrations.',
    );
    return parser;
  }
}

final class _AppleAppIntentsTestingCommand extends Command<int> {
  @override
  String get name => 'apple-appintents-testing';

  @override
  String get description =>
      'Generate/typecheck AppIntentsTesting live proof scaffolds.';

  @override
  Future<int> run() async {
    final subcommand = argResults!.command;
    if (subcommand == null) {
      printUsageError(
        'apple-appintents-testing requires generate-tests, generate-fixtures, or typecheck.',
      );
      return usageExitCode();
    }
    final projectRoot = _ProjectDirOption.read(argResults!);
    return runAppleAppIntentsTesting(subcommand, projectRoot);
  }

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    _ProjectDirOption.add(parser);
    for (final entry in buildAppleAppIntentsTestingParser().commands.entries) {
      parser.addCommand(entry.key, entry.value);
    }
    return parser;
  }
}
