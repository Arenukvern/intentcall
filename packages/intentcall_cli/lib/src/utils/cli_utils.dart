import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/intentcall_config.dart';

/// Resolves a project-relative or absolute path against [projectRoot].
File resolveProjectPath(final String projectRoot, final String path) {
  final normalized = p.normalize(path);
  if (p.isAbsolute(normalized)) {
    return File(normalized);
  }
  return File(p.join(projectRoot, normalized));
}

Directory resolveProjectDirectory(final String projectRoot, final String path) {
  final normalized = p.normalize(path);
  if (p.isAbsolute(normalized)) {
    return Directory(normalized);
  }
  return Directory(p.join(projectRoot, normalized));
}

String defaultProjectDir() => Directory.current.path;

IntentCallConfig? loadIntentCallConfig(final String projectRoot) {
  final configFile = File(p.join(projectRoot, 'intentcall.yaml'));
  if (!configFile.existsSync()) {
    return null;
  }
  return IntentCallConfig.parse(
    configFile.readAsStringSync(),
    sourcePath: configFile.path,
  );
}

File resolveManifestOutput(final String projectRoot, {final IntentCallConfig? config}) {
  final rel = config?.layout.manifest ?? 'web/agent_manifest.json';
  return resolveProjectPath(projectRoot, rel);
}

String encodePrettyJson(final Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

Map<String, Object?> readJsonObjectFile(final File file) {
  if (!file.existsSync()) {
    throw FormatException('JSON file not found: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  return switch (decoded) {
    final Map<String, Object?> typed => typed,
    final Map map => map.cast<String, Object?>(),
    _ => throw FormatException('JSON file must contain an object: ${file.path}'),
  };
}

void printJson(final Object? value) {
  stdout.writeln(encodePrettyJson(value));
}

void printUsageError(final String message) {
  stderr.writeln('FAIL: $message');
}

int usageExitCode() => 64;

int dataErrorExitCode() => 65;

int inputMissingExitCode() => 66;

List<String> parsePlatformList(final Iterable<String> values) {
  final out = <String>{};
  for (final value in values) {
    for (final part in value.split(',')) {
      final trimmed = part.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
  }
  return out.toList()..sort();
}

String? readPackageName(final String projectRoot) {
  final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return null;
  }
  final match = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  return match?.group(1);
}
