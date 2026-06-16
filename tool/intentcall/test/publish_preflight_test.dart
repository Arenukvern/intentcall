import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/intentcall.dart' as intentcall_cli;

void main() {
  group('publish args', () {
    test('strict dry-run does not ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: true, ignoreWarnings: false),
        ['pub', 'publish', '--dry-run'],
      );
    });

    test('diagnostic dry-run can ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: true, ignoreWarnings: true),
        ['pub', 'publish', '--dry-run', '--ignore-warnings'],
      );
    });

    test('execute uses force without ignore warnings', () {
      expect(
        intentcall_cli.buildPublishArgs(dryRun: false, ignoreWarnings: false),
        ['pub', 'publish', '--force'],
      );
    });

    test('execute rejects ignore warnings', () async {
      final exitCode = await intentcall_cli.runPublishAll(
        Directory.systemTemp,
        dryRun: false,
        ignoreWarnings: true,
      );

      expect(exitCode, 64);
    });
  });

  group('runReleaseGitCleanCheck', () {
    test('passes when release-critical files are clean', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 0);
    });

    test('fails for untracked files in publish package tree', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'intentcall_core', 'lib', 'new_api.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('fails for modified tracked files in publish package tree', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'intentcall_core', 'lib', 'api.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');
      await _runGit(repo, ['add', '.']);
      await _runGit(repo, [
        '-c',
        'user.name=IntentCall Test',
        '-c',
        'user.email=intentcall@example.invalid',
        'commit',
        '-m',
        'initial',
      ]);
      file.writeAsStringSync('library;\n\nfinal answer = 42;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('fails for untracked files in release tooling', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'tool', 'intentcall', 'lib', 'publish_helper.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 1);
    });

    test('ignores untracked files outside release-critical paths', () async {
      final repo = await _createGitRepo();
      addTearDown(() => repo.deleteSync(recursive: true));
      final file = File(
        p.join(repo.path, 'packages', 'scratch_tool', 'lib', 'scratch.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('library;\n');

      final exitCode = await intentcall_cli.runReleaseGitCleanCheck(repo);

      expect(exitCode, 0);
    });
  });
}

Future<Directory> _createGitRepo() async {
  final repo = await Directory.systemTemp.createTemp('intentcall_cli_test_');
  final result = await Process.run('git', [
    'init',
  ], workingDirectory: repo.path);
  if (result.exitCode != 0) {
    throw StateError('git init failed: ${result.stderr}');
  }
  return repo;
}

Future<void> _runGit(Directory repo, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: repo.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}
