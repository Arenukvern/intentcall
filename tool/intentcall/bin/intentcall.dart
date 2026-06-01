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
  print('  check-path-deps       Scan workspace for invalid path dependencies.');
  print('  print-hosted-deps     Print hosted pub.dev dependency blocks.');
  print('  publish-all           Publish all workspace packages to pub.dev in order.');
  print('\nOptions:');
  print(parser.usage);
}

Future<int> runCheckPathDeps(Directory repoRoot) async {
  final targetDirs = ['mcp_toolkit', 'mcp_server_dart', 'packages', 'flutter_test_app'];
  bool foundPathDep = false;

  for (final dirName in targetDirs) {
    final dir = Directory(p.join(repoRoot.path, dirName));
    if (!dir.existsSync()) continue;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
        final parts = p.split(entity.path);
        if (parts.contains('.dart_tool') || parts.contains('build')) {
          continue;
        }

        final content = await entity.readAsString();
        if (content.contains('intentcall/packages')) {
          print('path dep still present: ${p.relative(entity.path, from: repoRoot.path)}');
          final lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('intentcall/packages')) {
              print('  Line ${i + 1}: ${lines[i].trim()}');
            }
          }
          foundPathDep = true;
        }
      }
    }
  }

  if (foundPathDep) {
    stderr.writeln('FAIL: migrate to hosted intentcall deps (see docs/intentcall/hosted_cutover.md)');
    return 1;
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
