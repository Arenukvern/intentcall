import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads the package `name` from [projectRoot]/pubspec.yaml.
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
