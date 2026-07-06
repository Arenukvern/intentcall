import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of ensuring generated AppIntent Swift is compiled by Runner.
final class AppleXcodeProjectSyncResult {
  const AppleXcodeProjectSyncResult({
    required this.projectPath,
    required this.changed,
  });

  final String projectPath;
  final bool changed;
}

/// Maintains the generated IntentCall Swift file in a Flutter Runner target.
final class AppleXcodeProjectSync {
  const AppleXcodeProjectSync({
    this.generatedFileName = 'IntentCallGenerated.swift',
    this.staleGeneratedFileNames = const <String>['IntentCallGenerated.swift'],
  });

  final String generatedFileName;
  final Iterable<String> staleGeneratedFileNames;

  AppleXcodeProjectSyncResult sync({
    required final String appleRoot,
    final bool dryRun = false,
  }) {
    final projectFile = File(
      p.join(appleRoot, 'Runner.xcodeproj', 'project.pbxproj'),
    );
    final next = _desiredContent(projectFile);
    final changed = next != projectFile.readAsStringSync();
    if (changed && !dryRun) {
      projectFile.writeAsStringSync(next);
    }
    return AppleXcodeProjectSyncResult(
      projectPath: projectFile.path,
      changed: changed,
    );
  }

  bool check(final String appleRoot) {
    final projectFile = File(
      p.join(appleRoot, 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (!projectFile.existsSync()) {
      return false;
    }
    return _desiredContent(projectFile) == projectFile.readAsStringSync();
  }

  String _desiredContent(final File projectFile) {
    if (!projectFile.existsSync()) {
      throw StateError('Missing Xcode project file: ${projectFile.path}');
    }
    var content = projectFile.readAsStringSync();
    final sourcesId = _runnerSourcesBuildPhaseId(content, projectFile.path);
    final runnerGroupId = _runnerGroupId(content, projectFile.path);
    final fileRefId = _stablePbxId('file:$generatedFileName');
    final buildFileId = _stablePbxId('build:$generatedFileName');

    content = _removeGeneratedReferences(content);
    content = _insertIntoSection(
      content,
      'PBXFileReference',
      '\t\t$fileRefId /* $generatedFileName */ = {isa = PBXFileReference; '
          'lastKnownFileType = sourcecode.swift; path = '
          'Generated/$generatedFileName; sourceTree = "<group>"; };\n',
    );
    content = _insertIntoSection(
      content,
      'PBXBuildFile',
      '\t\t$buildFileId /* $generatedFileName in Sources */ = '
          '{isa = PBXBuildFile; fileRef = $fileRefId /* $generatedFileName */; };\n',
    );
    content = _insertIntoListBlock(
      content: content,
      objectId: runnerGroupId,
      listName: 'children',
      line: '\t\t\t\t$fileRefId /* $generatedFileName */,\n',
    );
    return _insertIntoListBlock(
      content: content,
      objectId: sourcesId,
      listName: 'files',
      line: '\t\t\t\t$buildFileId /* $generatedFileName in Sources */,\n',
    );
  }

  String _removeGeneratedReferences(final String content) {
    final generatedNames = <String>{
      generatedFileName,
      ...staleGeneratedFileNames,
    };
    return content
        .split('\n')
        .where((final line) => !_isGeneratedReferenceLine(line, generatedNames))
        .join('\n');
  }

  bool _isGeneratedReferenceLine(final String line, final Set<String> names) {
    for (final name in names) {
      final escaped = RegExp.escape(name);
      final exactComment = RegExp(
        '/\\* $escaped(?: in Sources)? \\*/',
      ).hasMatch(line);
      final exactPath = RegExp(
        'path = (?:Generated/)?$escaped;',
      ).hasMatch(line);
      if (exactPath && exactComment) {
        return true;
      }
      final exactListEntry = RegExp(
        '^\\s*[0-9A-F]{24} /\\* $escaped(?: in Sources)? \\*/,\\s*\$',
      ).hasMatch(line);
      if (exactListEntry) {
        return true;
      }
      final buildFile =
          line.contains('isa = PBXBuildFile;') &&
          line.contains('/* $name in Sources */') &&
          line.contains('/* $name */');
      if (buildFile) {
        return true;
      }
    }
    return false;
  }

  String _insertIntoSection(
    final String content,
    final String sectionName,
    final String entry,
  ) {
    final marker = '/* End $sectionName section */';
    final index = content.indexOf(marker);
    if (index == -1) {
      throw StateError(
        'Unsupported Xcode project: missing $sectionName section',
      );
    }
    return content.replaceRange(index, index, entry);
  }

  String _insertIntoListBlock({
    required final String content,
    required final String objectId,
    required final String listName,
    required final String line,
  }) {
    final objectMatch = RegExp(
      '^\\t\\t${RegExp.escape(objectId)} .* = \\{',
      multiLine: true,
    ).firstMatch(content);
    if (objectMatch == null) {
      throw StateError('Unsupported Xcode project: missing object $objectId');
    }
    final objectStart = objectMatch.start;
    final objectEnd = content.indexOf('\n\t\t};', objectStart);
    if (objectEnd == -1) {
      throw StateError('Unsupported Xcode project: malformed object $objectId');
    }
    final listStart = content.indexOf('\n\t\t\t$listName = (\n', objectStart);
    if (listStart == -1 || listStart > objectEnd) {
      throw StateError(
        'Unsupported Xcode project: missing $listName list in object $objectId',
      );
    }
    final listEnd = content.indexOf('\n\t\t\t);', listStart);
    if (listEnd == -1 || listEnd > objectEnd) {
      throw StateError(
        'Unsupported Xcode project: malformed $listName list in object $objectId',
      );
    }
    return content.replaceRange(listEnd + 1, listEnd + 1, line);
  }

  String _runnerSourcesBuildPhaseId(
    final String content,
    final String projectPath,
  ) {
    for (final targetMatch in RegExp(
      r'\t\t[0-9A-F]{24} /\* Runner \*/ = \{[\s\S]*?\n\t\t\};',
    ).allMatches(content)) {
      final block = targetMatch.group(0)!;
      if (!block.contains('isa = PBXNativeTarget;')) {
        continue;
      }
      final phaseMatch = RegExp(
        r'\n\t\t\t\t([0-9A-F]{24}) /\* Sources \*/,',
      ).firstMatch(block);
      if (phaseMatch == null) {
        throw StateError(
          'Unsupported Xcode project: Runner target has no Sources phase in $projectPath',
        );
      }
      return phaseMatch.group(1)!;
    }
    throw StateError(
      'Unsupported Xcode project: missing Runner native target in $projectPath',
    );
  }

  String _runnerGroupId(final String content, final String projectPath) {
    final groupSectionMatch = RegExp(
      r'/\* Begin PBXGroup section \*/[\s\S]*?/\* End PBXGroup section \*/',
    ).firstMatch(content);
    if (groupSectionMatch == null) {
      throw StateError(
        'Unsupported Xcode project: missing PBXGroup section in $projectPath',
      );
    }
    for (final match in RegExp(
      r'\t\t([0-9A-F]{24}) /\* Runner \*/ = \{[\s\S]*?\n\t\t\};',
    ).allMatches(groupSectionMatch.group(0)!)) {
      final block = match.group(0)!;
      if (block.contains('isa = PBXGroup;') &&
          block.contains('\n\t\t\tchildren = (')) {
        return match.group(1)!;
      }
    }
    throw StateError(
      'Unsupported Xcode project: missing Runner group in $projectPath',
    );
  }

  String _stablePbxId(final String seed) {
    var value = 0x811C9DC5;
    final out = StringBuffer();
    var round = 0;
    while (out.length < 24) {
      for (final unit in '$seed:$round'.codeUnits) {
        value ^= unit;
        value = (value * 0x01000193) & 0xFFFFFFFF;
      }
      out.write(value.toRadixString(16).padLeft(8, '0'));
      round += 1;
    }
    return out.toString().substring(0, 24).toUpperCase();
  }
}
