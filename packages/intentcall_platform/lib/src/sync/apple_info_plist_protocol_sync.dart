import 'dart:io';

import 'package:path/path.dart' as p;

import '../emitters/emitter_utils.dart';

/// Result of ensuring an Apple Runner Info.plist declares the fallback scheme.
final class AppleInfoPlistProtocolSyncResult {
  const AppleInfoPlistProtocolSyncResult({
    required this.infoPlistPath,
    required this.changed,
  });

  final String infoPlistPath;
  final bool changed;
}

/// Maintains `CFBundleURLTypes` for generated open-app App Intents.
final class AppleInfoPlistProtocolSync {
  const AppleInfoPlistProtocolSync({this.infoPlistPath = 'Runner/Info.plist'});

  final String infoPlistPath;

  AppleInfoPlistProtocolSyncResult sync({
    required final String appleRoot,
    required final String protocolScheme,
    final bool dryRun = false,
  }) {
    final plistFile = File(p.join(appleRoot, infoPlistPath));
    final next = _desiredContent(plistFile, protocolScheme);
    final changed = next != plistFile.readAsStringSync();
    if (changed && !dryRun) {
      plistFile.writeAsStringSync(next);
    }
    return AppleInfoPlistProtocolSyncResult(
      infoPlistPath: plistFile.path,
      changed: changed,
    );
  }

  bool check({
    required final String appleRoot,
    required final String protocolScheme,
  }) {
    final plistFile = File(p.join(appleRoot, infoPlistPath));
    if (!plistFile.existsSync()) {
      return false;
    }
    return _containsProtocolScheme(
      plistFile.readAsStringSync(),
      _validatedScheme(protocolScheme),
    );
  }

  String _desiredContent(final File plistFile, final String protocolScheme) {
    if (!plistFile.existsSync()) {
      throw StateError('Missing Info.plist file: ${plistFile.path}');
    }
    final scheme = _validatedScheme(protocolScheme);
    final content = plistFile.readAsStringSync();
    if (_containsProtocolScheme(content, scheme)) {
      return content;
    }

    final urlTypesKey = RegExp(
      r'<key>\s*CFBundleURLTypes\s*</key>',
    ).firstMatch(content);
    if (urlTypesKey != null) {
      final arrayStart = _firstTagStart(content, 'array', urlTypesKey.end);
      if (arrayStart == -1) {
        throw StateError(
          'Unsupported Info.plist: CFBundleURLTypes is not an array in '
          '${plistFile.path}',
        );
      }
      final arrayEnd = _matchingContainerClose(content, arrayStart);
      final indent = _lineIndentBefore(content, arrayEnd);
      return content.replaceRange(
        arrayEnd,
        arrayEnd,
        _urlTypeDictXml(scheme, indent),
      );
    }

    final rootDictStart = _firstTagStart(content, 'dict', 0);
    if (rootDictStart == -1) {
      throw StateError(
        'Unsupported Info.plist: missing top-level dict in ${plistFile.path}',
      );
    }
    final rootDictEnd = _matchingContainerClose(content, rootDictStart);
    final indent = _lineIndentBefore(content, rootDictEnd);
    return content.replaceRange(
      rootDictEnd,
      rootDictEnd,
      _urlTypesXml(scheme, indent),
    );
  }

  bool _containsProtocolScheme(final String content, final String scheme) {
    final escapedScheme = RegExp.escape(escapeXml(scheme));
    for (final match in RegExp(
      r'<key>\s*CFBundleURLSchemes\s*</key>\s*<array>([\s\S]*?)</array>',
    ).allMatches(content)) {
      final schemes = match.group(1)!;
      if (RegExp('<string>\\s*$escapedScheme\\s*</string>').hasMatch(schemes)) {
        return true;
      }
    }
    return false;
  }

  String _validatedScheme(final String protocolScheme) =>
      requireProtocolScheme(protocolScheme, artifact: 'Apple Info.plist');

  int _firstTagStart(
    final String content,
    final String tagName,
    final int start,
  ) {
    final match = RegExp(
      '<$tagName(?:\\s[^>]*)?>',
    ).firstMatch(content.substring(start));
    return match == null ? -1 : start + match.start;
  }

  int _matchingContainerClose(final String content, final int openTagStart) {
    final first = RegExp(
      r'<(/?)(array|dict)(?:\s[^>]*)?>',
    ).firstMatch(content.substring(openTagStart));
    if (first == null || first.group(1) == '/') {
      throw StateError('Unsupported plist XML: missing container start.');
    }

    final stack = <String>[];
    final scanner = RegExp(r'<(/?)(array|dict)(?:\s[^>]*)?>');
    for (final match in scanner.allMatches(content, openTagStart)) {
      final closing = match.group(1) == '/';
      final tag = match.group(2)!;
      if (!closing) {
        stack.add(tag);
        continue;
      }
      if (stack.isEmpty || stack.last != tag) {
        throw StateError('Unsupported plist XML: malformed containers.');
      }
      stack.removeLast();
      if (stack.isEmpty) {
        return match.start;
      }
    }
    throw StateError('Unsupported plist XML: unterminated container.');
  }

  String _lineIndentBefore(final String content, final int index) {
    final lineStart = content.lastIndexOf('\n', index - 1) + 1;
    final linePrefix = content.substring(lineStart, index);
    final indent = RegExp(r'^\s*').firstMatch(linePrefix)?.group(0) ?? '';
    return indent.isEmpty ? '\t' : indent;
  }

  String _urlTypesXml(final String scheme, final String indent) {
    final child = '$indent\t';
    return '''
$indent<key>CFBundleURLTypes</key>
$indent<array>
${_urlTypeDictXml(scheme, child)}$indent</array>
''';
  }

  String _urlTypeDictXml(final String scheme, final String indent) {
    final child = '$indent\t';
    final grandchild = '$child\t';
    final escapedScheme = escapeXml(scheme);
    return '''
$indent<dict>
$child<key>CFBundleTypeRole</key>
$child<string>Editor</string>
$child<key>CFBundleURLName</key>
$child<string>$escapedScheme</string>
$child<key>CFBundleURLSchemes</key>
$child<array>
$grandchild<string>$escapedScheme</string>
$child</array>
$indent</dict>
''';
  }
}
