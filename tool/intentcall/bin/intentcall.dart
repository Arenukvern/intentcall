// ignore_for_file: avoid_print, prefer_final_parameters, avoid_catches_without_on_clauses, prefer_if_elements_to_conditional_expressions

import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const publishOrder = [
  'intentcall_schema',
  'intentcall_core',
  'intentcall_mcp',
  'intentcall_webmcp',
  'intentcall_gemma',
  'intentcall_apple',
  'intentcall_android',
  'intentcall_codegen',
  'intentcall_platform',
  'intentcall_testing',
];

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('doctor')
    ..addCommand('validate')
    ..addCommand('check-path-deps')
    ..addCommand(
      'print-hosted-deps',
      ArgParser()..addOption('version', abbr: 'v', help: 'Version to print dependencies for'),
    )
    ..addCommand(
      'publish-all',
      ArgParser()
        ..addFlag('execute', negatable: false, help: 'Execute publishing instead of dry-run')
        ..addFlag('dry-run', negatable: false, help: 'Run publish in dry-run mode (default)', defaultsTo: true),
    );

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e');
    printUsage(parser);
    exit(64);
  }

  if (results.command == null) {
    printUsage(parser);
    exit(64);
  }

  final repoRoot = findRepoRoot();

  switch (results.command!.name) {
    case 'doctor':
      final code = await runDoctor(repoRoot);
      exit(code);

    case 'validate':
      final code = await runValidate(repoRoot);
      exit(code);

    case 'check-path-deps':
      final code = await runCheckPathDeps(repoRoot);
      exit(code);

    case 'print-hosted-deps':
      final cmdResults = results.command!;
      final envVersion = Platform.environment['INTENTCALL_VERSION'];
      final version = cmdResults['version'] as String? ?? envVersion ?? '0.1.0';
      runPrintHostedDeps(version);
      exit(0);

    case 'publish-all':
      final cmdResults = results.command!;
      // If --execute is passed, dryRun is false. If only --dry-run is passed or neither, dryRun is true.
      final execute = cmdResults['execute'] as bool? ?? false;
      final dryRun = !execute;
      final code = await runPublishAll(repoRoot, dryRun: dryRun);
      exit(code);

    default:
      printUsage(parser);
      exit(64);
  }
}

Directory findRepoRoot() {
  var dir = Directory(p.dirname(Platform.script.toFilePath()));
  while (dir.path != dir.parent.path) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: intentcall_workspace')) {
        return dir;
      }
    }
    dir = dir.parent;
  }
  // Fallback to current directory
  return Directory.current;
}

void printUsage(ArgParser parser) {
  print('Usage: dart run tool/intentcall [command] [options]');
  print('\nCommands:');
  print('  doctor                Check developer environment health.');
  print('  validate              Validate path dependencies and version consistency.');
  print('  check-path-deps       Scan workspace for invalid path dependencies.');
  print('  print-hosted-deps     Print hosted pub.dev dependency blocks.');
  print('  publish-all           Publish all workspace packages to pub.dev in order.');
  print('\nOptions:');
  print(parser.usage);
}

Future<int> runDoctor(Directory repoRoot) async {
  print('== IntentCall Workspace Doctor ==');
  bool healthy = true;

  // 1. Check Dart CLI
  try {
    final result = await Process.run('dart', ['--version']);
    if (result.exitCode == 0) {
      print('✓ Dart SDK: ${result.stdout.toString().trim()}');
    } else {
      print('✗ Dart SDK check failed');
      healthy = false;
    }
  } catch (e) {
    print('✗ Dart SDK not found in PATH: $e');
    healthy = false;
  }

  // 2. Check Flutter CLI (needed for intentcall_platform)
  try {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode == 0) {
      final line = result.stdout.toString().split('\n').first;
      print('✓ Flutter SDK: $line');
    } else {
      print('✗ Flutter SDK check failed');
      healthy = false;
    }
  } catch (e) {
    print('✗ Flutter SDK not found in PATH: $e');
    healthy = false;
  }

  // 3. Check just task runner
  try {
    final result = await Process.run('just', ['--version']);
    if (result.exitCode == 0) {
      print('✓ just task runner: ${result.stdout.toString().trim()}');
    } else {
      print('✗ just check failed');
      healthy = false;
    }
  } catch (e) {
    print('? just task runner not found (optional but recommended): $e');
  }

  // 4. Check workspace lockfile
  final lockFile = File(p.join(repoRoot.path, 'pubspec.lock'));
  if (lockFile.existsSync()) {
    print('✓ Workspace pubspec.lock exists');
  } else {
    print('✗ Workspace pubspec.lock is missing. Run "dart pub get"');
    healthy = false;
  }

  if (healthy) {
    print('\nWorkspace status: HEALTHY');
    return 0;
  } else {
    print('\nWorkspace status: UNHEALTHY (Please check the issues above)');
    return 1;
  }
}

Future<int> runValidate(Directory repoRoot) async {
  print('== Running Workspace Validation ==');
  
  // 1. Run check-path-deps
  final pathDepsExitCode = await runCheckPathDeps(repoRoot);
  if (pathDepsExitCode != 0) {
    return pathDepsExitCode;
  }
  
  // 2. Run version consistency check
  print('\nChecking version consistency across packages...');
  String? commonVersion;
  bool versionMismatch = false;
  
  for (final pkg in publishOrder) {
    final pubspecFile = File(p.join(repoRoot.path, 'packages', pkg, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('ERROR: pubspec.yaml not found for package: $pkg');
      return 1;
    }
    
    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(content);
    if (versionMatch == null) {
      stderr.writeln('ERROR: Could not find version in pubspec.yaml for package: $pkg');
      return 1;
    }
    
    final version = versionMatch.group(1);
    print('  - $pkg: $version');
    if (commonVersion == null) {
      commonVersion = version;
    } else if (commonVersion != version) {
      stderr.writeln('ERROR: Version mismatch for package $pkg ($version). Expected $commonVersion.');
      versionMismatch = true;
    }
  }
  
  if (versionMismatch) {
    stderr.writeln('FAIL: Package versions are not synchronized.');
    return 1;
  }
  
  print('OK: All packages are synchronized at version $commonVersion.');

  // 3. Run plan hygiene check
  print('\nChecking plan hygiene (active plan files)...');
  final activePlans = <String>[];
  final taskFile = File(p.join(repoRoot.path, 'task.md'));
  if (taskFile.existsSync()) activePlans.add('task.md');
  final planFile = File(p.join(repoRoot.path, 'implementation_plan.md'));
  if (planFile.existsSync()) activePlans.add('implementation_plan.md');
  
  final activePlansDir = Directory(p.join(repoRoot.path, 'docs', 'exec-plans', 'active'));
  if (activePlansDir.existsSync()) {
    try {
      final files = activePlansDir.listSync().whereType<File>();
      for (final f in files) {
        final name = p.basename(f.path);
        if (!name.startsWith('.')) {
          activePlans.add('docs/exec-plans/active/$name');
        }
      }
    } catch (_) {}
  }
  
  if (activePlans.isNotEmpty) {
    stderr.writeln('FAIL: Stale/active plan files found: ${activePlans.join(", ")}');
    stderr.writeln('Please extract durable findings to docs/decisions/ or DESIGN_FAQ.mdx, then delete the plan files.');
    return 1;
  }
  
  print('OK: No active plan files found.');
  return 0;
}

Future<int> runCheckPathDeps(Directory repoRoot) async {
  print('Running declarative validation via steward...');
  final result = await Process.run(
    '/Users/anton/.local/bin/steward',
    ['validate'],
    workingDirectory: repoRoot.path,
  );
  if (result.stdout.toString().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr.toString().isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    return result.exitCode;
  }

  print('OK: no intentcall path deps in consumers');
  return 0;
}

void runPrintHostedDeps(String version) {
  print('# Replace path: ../intentcall/packages/<name> with:');
  print('');
  for (final pkg in publishOrder) {
    print('$pkg: ^$version');
  }
}

Future<int> runPublishAll(Directory repoRoot, {required bool dryRun}) async {
  print('== Workspace pub get ==');
  final pubGetCode = await runCommand('dart', ['pub', 'get'], repoRoot.path);
  if (pubGetCode != 0) {
    stderr.writeln('FAIL: workspace pub get failed');
    return pubGetCode;
  }

  for (final pkg in publishOrder) {
    final dirPath = p.join(repoRoot.path, 'packages', pkg);
    print('\n== Publishing package: $pkg ==');

    final isPlatform = pkg == 'intentcall_platform';
    final exec = isPlatform ? 'flutter' : 'dart';
    final args = ['pub', 'publish', dryRun ? '--dry-run' : '--force'];

    final exitCode = await runCommand(exec, args, dirPath);
    if (exitCode != 0) {
      stderr.writeln('FAIL: publishing $pkg failed with exit code $exitCode');
      return exitCode;
    }
  }

  print('\nOK: publish_all complete (dryRun=$dryRun)');
  return 0;
}

Future<int> runCommand(String executable, List<String> arguments, String workingDirectory) async {
  print('Running command: $executable ${arguments.join(' ')} (in $workingDirectory)');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
