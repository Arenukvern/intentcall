import 'dart:io';

import 'package:path/path.dart' as p;

import '../agent_manifest.dart';
import '../emitters/android_shortcuts_xml_emitter.dart';
import '../emitters/apple_swift_app_intents_emitter.dart';
import '../emitters/linux_desktop_entry_emitter.dart';
import '../emitters/web_manifest_emitter.dart';
import '../emitters/web_mcp_js_emitter.dart';
import '../emitters/windows_protocol_emitter.dart';
import 'apple_info_plist_protocol_sync.dart';
import 'apple_xcode_project_sync.dart';

/// Supported `codegen sync --platform` values.
const kPlatformSyncTargets = <String>{
  'web',
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
};

/// Result of syncing platform artifacts into a Flutter project.
final class PlatformSyncResult {
  const PlatformSyncResult({
    required this.manifestPath,
    this.dryRun = false,
    this.artifacts = const <PlatformSyncArtifact>[],
    this.webManifestPath,
    this.webMcpJsPath,
    this.androidShortcutsPath,
    this.iosGeneratedSwiftPath,
    this.macosGeneratedSwiftPath,
    this.iosXcodeProjectPath,
    this.macosXcodeProjectPath,
    this.iosInfoPlistPath,
    this.macosInfoPlistPath,
    this.linuxDesktopPath,
    this.windowsProtocolPath,
    this.windowsMsixFragmentPath,
    this.wroteManifest = false,
    this.wroteWebMcpJs = false,
    this.wroteAndroidShortcuts = false,
    this.wroteIosGenerated = false,
    this.wroteMacosGenerated = false,
    this.wroteIosXcodeProject = false,
    this.wroteMacosXcodeProject = false,
    this.wroteIosInfoPlist = false,
    this.wroteMacosInfoPlist = false,
    this.wroteLinuxDesktop = false,
    this.wroteWindowsProtocol = false,
    this.wroteWindowsMsixFragment = false,
  });

  final String manifestPath;
  final bool dryRun;
  final List<PlatformSyncArtifact> artifacts;
  final String? webManifestPath;
  final String? webMcpJsPath;
  final String? androidShortcutsPath;
  final String? iosGeneratedSwiftPath;
  final String? macosGeneratedSwiftPath;
  final String? iosXcodeProjectPath;
  final String? macosXcodeProjectPath;
  final String? iosInfoPlistPath;
  final String? macosInfoPlistPath;
  final String? linuxDesktopPath;
  final String? windowsProtocolPath;
  final String? windowsMsixFragmentPath;
  final bool wroteManifest;
  final bool wroteWebMcpJs;
  final bool wroteAndroidShortcuts;
  final bool wroteIosGenerated;
  final bool wroteMacosGenerated;
  final bool wroteIosXcodeProject;
  final bool wroteMacosXcodeProject;
  final bool wroteIosInfoPlist;
  final bool wroteMacosInfoPlist;
  final bool wroteLinuxDesktop;
  final bool wroteWindowsProtocol;
  final bool wroteWindowsMsixFragment;

  bool get changed => artifacts.any((final artifact) => artifact.changed);
}

/// One generated or maintained platform artifact touched by [PlatformSync].
final class PlatformSyncArtifact {
  const PlatformSyncArtifact({
    required this.target,
    required this.kind,
    required this.path,
    required this.changed,
    this.operation = 'write',
  });

  final String target;
  final String kind;
  final String path;
  final bool changed;

  /// Stable operation label, for example `write` or `target-membership`.
  final String operation;
}

/// Writes platform artifacts from [agent_manifest.json].
final class PlatformSync {
  const PlatformSync({
    this.manifestFileName = 'agent_manifest.json',
    this.webDirName = 'web',
    this.androidDirName = 'android',
    this.iosDirName = 'ios',
    this.macosDirName = 'macos',
    this.linuxDirName = 'linux',
    this.windowsDirName = 'windows',
    this.webManifestFileName = 'manifest.json',
    this.webMcpJsFileName = 'intentcall_webmcp.generated.js',
    this.androidShortcutsFileName = 'intentcall_shortcuts.xml',
    this.appleGeneratedFileName = 'IntentCallGenerated.swift',
    this.linuxDesktopFileName = 'intentcall_protocol.desktop',
    this.windowsProtocolFileName = 'intentcall_protocol.reg',
    this.windowsMsixFragmentFileName = 'intentcall_protocol_msix.xml',
    this.webManifestEmitter = const WebManifestEmitter(),
    this.webMcpJsEmitter = const WebMcpJsEmitter(),
    this.androidShortcutsEmitter = const AndroidShortcutsXmlEmitter(),
    this.appleSwiftEmitter = const AppleSwiftAppIntentsEmitter(),
    this.linuxDesktopEmitter = const LinuxDesktopEntryEmitter(),
    this.windowsProtocolEmitter = const WindowsProtocolEmitter(),
  });

  final String manifestFileName;
  final String webDirName;
  final String androidDirName;
  final String iosDirName;
  final String macosDirName;
  final String linuxDirName;
  final String windowsDirName;
  final String webManifestFileName;
  final String webMcpJsFileName;
  final String androidShortcutsFileName;
  final String appleGeneratedFileName;
  final String linuxDesktopFileName;
  final String windowsProtocolFileName;
  final String windowsMsixFragmentFileName;
  final WebManifestEmitter webManifestEmitter;
  final WebMcpJsEmitter webMcpJsEmitter;
  final AndroidShortcutsXmlEmitter androidShortcutsEmitter;
  final AppleSwiftAppIntentsEmitter appleSwiftEmitter;
  final LinuxDesktopEntryEmitter linuxDesktopEmitter;
  final WindowsProtocolEmitter windowsProtocolEmitter;

  AgentManifest readManifest(final String projectRoot) {
    final manifestFile = _resolveManifestFile(projectRoot);
    if (!manifestFile.existsSync()) {
      throw StateError(
        'Missing $manifestFileName at ${manifestFile.path}. '
        'Maintain web/agent_manifest.json (or project-root copy) from your '
        'agent descriptor list, or run `intentcall platform sync`.',
      );
    }
    return AgentManifest.parse(manifestFile.readAsStringSync());
  }

  /// Syncs one or more platforms; returns merged [PlatformSyncResult].
  PlatformSyncResult syncPlatforms({
    required final String projectRoot,
    required final Iterable<String> platforms,
    final bool dryRun = false,
  }) {
    final normalized = platforms
        .map((final value) => value.trim().toLowerCase())
        .where((final value) => value.isNotEmpty)
        .toSet();
    final unknown = normalized.difference(kPlatformSyncTargets);
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unsupported platform(s): ${unknown.join(', ')}');
    }

    var result = PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
    );
    for (final platform in normalized) {
      result = _mergeResults(result, switch (platform) {
        'web' => syncWeb(projectRoot: projectRoot, dryRun: dryRun),
        'android' => syncAndroid(projectRoot: projectRoot, dryRun: dryRun),
        'ios' => syncIos(projectRoot: projectRoot, dryRun: dryRun),
        'macos' => syncMacos(projectRoot: projectRoot, dryRun: dryRun),
        'linux' => syncLinux(projectRoot: projectRoot, dryRun: dryRun),
        'windows' => syncWindows(projectRoot: projectRoot, dryRun: dryRun),
        _ => throw StateError('unreachable'),
      });
    }
    return result;
  }

  PlatformSyncResult syncWeb({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final webDir = Directory(p.join(projectRoot, webDirName));
    if (!webDir.existsSync()) {
      throw StateError('Missing web/ directory under $projectRoot');
    }

    final webManifestFile = File(p.join(webDir.path, webManifestFileName));
    if (!webManifestFile.existsSync()) {
      throw StateError('Missing ${webManifestFile.path}');
    }

    final nextManifest = webManifestEmitter.emit(
      existingManifestJson: webManifestFile.readAsStringSync(),
      manifest: manifest,
    );
    final nextJs = webMcpJsEmitter.emit(manifest);
    final jsFile = File(p.join(webDir.path, webMcpJsFileName));
    final manifestChanged =
        webManifestFile.readAsStringSync() != '$nextManifest\n';
    final jsChanged =
        !jsFile.existsSync() || jsFile.readAsStringSync() != nextJs;

    var wroteManifest = false;
    var wroteJs = false;
    if (!dryRun) {
      if (manifestChanged) {
        webManifestFile.writeAsStringSync('$nextManifest\n');
        wroteManifest = true;
      }
      if (jsChanged) {
        jsFile.writeAsStringSync(nextJs);
        wroteJs = true;
      }
    }

    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
      artifacts: <PlatformSyncArtifact>[
        PlatformSyncArtifact(
          target: 'web',
          kind: 'web-manifest',
          path: webManifestFile.path,
          changed: manifestChanged,
        ),
        PlatformSyncArtifact(
          target: 'web',
          kind: 'webmcp-js',
          path: jsFile.path,
          changed: jsChanged,
        ),
      ],
      webManifestPath: webManifestFile.path,
      webMcpJsPath: jsFile.path,
      wroteManifest: wroteManifest,
      wroteWebMcpJs: wroteJs,
    );
  }

  PlatformSyncResult syncAndroid({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final outFile = _androidShortcutsFile(projectRoot);
    final next = '${androidShortcutsEmitter.emit(manifest)}\n';
    final changed = !outFile.existsSync() || outFile.readAsStringSync() != next;
    var wrote = false;
    if (!dryRun) {
      outFile.parent.createSync(recursive: true);
      if (changed) {
        outFile.writeAsStringSync(next);
        wrote = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
      artifacts: <PlatformSyncArtifact>[
        PlatformSyncArtifact(
          target: 'android',
          kind: 'shortcuts-xml',
          path: outFile.path,
          changed: changed,
        ),
      ],
      androidShortcutsPath: outFile.path,
      wroteAndroidShortcuts: wrote,
    );
  }

  PlatformSyncResult syncIos({
    required final String projectRoot,
    final bool dryRun = false,
  }) => _syncApple(
    projectRoot: projectRoot,
    appleRoot: p.join(projectRoot, iosDirName),
    isMacos: false,
    dryRun: dryRun,
  );

  PlatformSyncResult syncMacos({
    required final String projectRoot,
    final bool dryRun = false,
  }) => _syncApple(
    projectRoot: projectRoot,
    appleRoot: p.join(projectRoot, macosDirName),
    isMacos: true,
    dryRun: dryRun,
  );

  PlatformSyncResult syncLinux({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final linuxDir = Directory(p.join(projectRoot, linuxDirName));
    if (!linuxDir.existsSync()) {
      throw StateError('Missing linux/ directory under $projectRoot');
    }
    final outFile = File(p.join(linuxDir.path, linuxDesktopFileName));
    final next = linuxDesktopEmitter.emit(manifest);
    final changed = !outFile.existsSync() || outFile.readAsStringSync() != next;
    var wrote = false;
    if (!dryRun) {
      if (changed) {
        outFile.writeAsStringSync(next);
        wrote = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
      artifacts: <PlatformSyncArtifact>[
        PlatformSyncArtifact(
          target: 'linux',
          kind: 'desktop-entry',
          path: outFile.path,
          changed: changed,
        ),
      ],
      linuxDesktopPath: outFile.path,
      wroteLinuxDesktop: wrote,
    );
  }

  PlatformSyncResult syncWindows({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final windowsDir = Directory(p.join(projectRoot, windowsDirName));
    if (!windowsDir.existsSync()) {
      throw StateError('Missing windows/ directory under $projectRoot');
    }
    final regFile = File(p.join(windowsDir.path, windowsProtocolFileName));
    final msixFile = File(p.join(windowsDir.path, windowsMsixFragmentFileName));
    final nextReg = windowsProtocolEmitter.emit(manifest);
    final nextMsix = windowsProtocolEmitter.emitMsixFragment(manifest);
    final regChanged =
        !regFile.existsSync() || regFile.readAsStringSync() != nextReg;
    final msixChanged =
        !msixFile.existsSync() || msixFile.readAsStringSync() != nextMsix;
    var wroteReg = false;
    var wroteMsix = false;
    if (!dryRun) {
      if (regChanged) {
        regFile.writeAsStringSync(nextReg);
        wroteReg = true;
      }
      if (msixChanged) {
        msixFile.writeAsStringSync(nextMsix);
        wroteMsix = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
      artifacts: <PlatformSyncArtifact>[
        PlatformSyncArtifact(
          target: 'windows',
          kind: 'protocol-registry',
          path: regFile.path,
          changed: regChanged,
        ),
        PlatformSyncArtifact(
          target: 'windows',
          kind: 'protocol-msix-fragment',
          path: msixFile.path,
          changed: msixChanged,
        ),
      ],
      windowsProtocolPath: regFile.path,
      windowsMsixFragmentPath: msixFile.path,
      wroteWindowsProtocol: wroteReg,
      wroteWindowsMsixFragment: wroteMsix,
    );
  }

  bool checkPlatforms(
    final String projectRoot,
    final Iterable<String> platforms,
  ) {
    for (final platform in platforms) {
      final ok = switch (platform.trim().toLowerCase()) {
        'web' => checkWeb(projectRoot),
        'android' => checkAndroid(projectRoot),
        'ios' => checkIos(projectRoot),
        'macos' => checkMacos(projectRoot),
        'linux' => checkLinux(projectRoot),
        'windows' => checkWindows(projectRoot),
        _ => false,
      };
      if (!ok) {
        return false;
      }
    }
    return true;
  }

  /// Returns `true` when generated web outputs already match emitters.
  bool checkWeb(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final webDir = p.join(projectRoot, webDirName);
    final webManifestFile = File(p.join(webDir, webManifestFileName));
    final jsFile = File(p.join(webDir, webMcpJsFileName));
    if (!webManifestFile.existsSync() || !jsFile.existsSync()) {
      return false;
    }
    final expectedManifest = webManifestEmitter.emit(
      existingManifestJson: webManifestFile.readAsStringSync(),
      manifest: manifest,
    );
    final expectedJs = webMcpJsEmitter.emit(manifest);
    return webManifestFile.readAsStringSync() == '$expectedManifest\n' &&
        jsFile.readAsStringSync() == expectedJs;
  }

  bool checkAndroid(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final file = _androidShortcutsFile(projectRoot);
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() ==
        '${androidShortcutsEmitter.emit(manifest)}\n';
  }

  bool checkIos(final String projectRoot) =>
      _checkApple(projectRoot: projectRoot, appleRoot: iosDirName);

  bool checkMacos(final String projectRoot) =>
      _checkApple(projectRoot: projectRoot, appleRoot: macosDirName);

  bool checkLinux(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final file = File(p.join(projectRoot, linuxDirName, linuxDesktopFileName));
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() == linuxDesktopEmitter.emit(manifest);
  }

  bool checkWindows(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final reg = File(
      p.join(projectRoot, windowsDirName, windowsProtocolFileName),
    );
    final msix = File(
      p.join(projectRoot, windowsDirName, windowsMsixFragmentFileName),
    );
    if (!reg.existsSync() || !msix.existsSync()) {
      return false;
    }
    return reg.readAsStringSync() == windowsProtocolEmitter.emit(manifest) &&
        msix.readAsStringSync() ==
            windowsProtocolEmitter.emitMsixFragment(manifest);
  }

  PlatformSyncResult _syncApple({
    required final String projectRoot,
    required final String appleRoot,
    required final bool isMacos,
    required final bool dryRun,
  }) {
    final manifest = readManifest(projectRoot);
    final rootDir = Directory(appleRoot);
    if (!rootDir.existsSync()) {
      throw StateError('Missing $appleRoot directory under $projectRoot');
    }
    final generatedDir = Directory(p.join(appleRoot, 'Runner', 'Generated'));
    final outFile = File(p.join(generatedDir.path, appleGeneratedFileName));
    final next = '${appleSwiftEmitter.emit(manifest)}\n';
    final generatedChanged =
        !outFile.existsSync() || outFile.readAsStringSync() != next;
    final projectSync = _appleXcodeProjectSync();
    final xcodePreview = projectSync.sync(appleRoot: appleRoot, dryRun: true);
    final protocolScheme = _appleOpenAppProtocolScheme(manifest);
    final plistPreview = protocolScheme == null
        ? null
        : _appleInfoPlistProtocolSync().sync(
            appleRoot: appleRoot,
            protocolScheme: protocolScheme,
            dryRun: true,
          );
    if (!dryRun) {
      generatedDir.createSync(recursive: true);
      _deleteStaleAppleGeneratedFiles(generatedDir);
      if (generatedChanged) {
        outFile.writeAsStringSync(next);
      }
    }
    final plistResult = !dryRun && plistPreview != null && plistPreview.changed
        ? _appleInfoPlistProtocolSync().sync(
            appleRoot: appleRoot,
            protocolScheme: protocolScheme!,
          )
        : plistPreview;
    final xcodeResult = !dryRun && xcodePreview.changed
        ? projectSync.sync(appleRoot: appleRoot)
        : xcodePreview;
    final target = isMacos ? 'macos' : 'ios';
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      dryRun: dryRun,
      artifacts: <PlatformSyncArtifact>[
        PlatformSyncArtifact(
          target: target,
          kind: 'apple-generated-swift',
          path: outFile.path,
          changed: generatedChanged,
        ),
        PlatformSyncArtifact(
          target: target,
          kind: 'xcode-project',
          path: xcodeResult.projectPath,
          changed: xcodeResult.changed,
          operation: 'target-membership',
        ),
        if (plistResult != null)
          PlatformSyncArtifact(
            target: target,
            kind: 'info-plist-url-scheme',
            path: plistResult.infoPlistPath,
            changed: plistResult.changed,
            operation: 'protocol-scheme',
          ),
      ],
      iosGeneratedSwiftPath: isMacos ? null : outFile.path,
      macosGeneratedSwiftPath: isMacos ? outFile.path : null,
      iosXcodeProjectPath: isMacos ? null : xcodeResult.projectPath,
      macosXcodeProjectPath: isMacos ? xcodeResult.projectPath : null,
      iosInfoPlistPath: isMacos ? null : plistResult?.infoPlistPath,
      macosInfoPlistPath: isMacos ? plistResult?.infoPlistPath : null,
      wroteIosGenerated: !isMacos && generatedChanged,
      wroteMacosGenerated: isMacos && generatedChanged,
      wroteIosXcodeProject: !isMacos && xcodeResult.changed,
      wroteMacosXcodeProject: isMacos && xcodeResult.changed,
      wroteIosInfoPlist: !isMacos && (plistResult?.changed ?? false),
      wroteMacosInfoPlist: isMacos && (plistResult?.changed ?? false),
    );
  }

  bool _checkApple({
    required final String projectRoot,
    required final String appleRoot,
  }) {
    final manifest = readManifest(projectRoot);
    final file = File(
      p.join(
        projectRoot,
        appleRoot,
        'Runner',
        'Generated',
        appleGeneratedFileName,
      ),
    );
    if (!file.existsSync()) {
      return false;
    }
    final protocolScheme = _appleOpenAppProtocolScheme(manifest);
    final appleProjectRoot = p.join(projectRoot, appleRoot);
    return file.readAsStringSync() == '${appleSwiftEmitter.emit(manifest)}\n' &&
        _appleXcodeProjectSync().check(appleProjectRoot) &&
        (protocolScheme == null ||
            _appleInfoPlistProtocolSync().check(
              appleRoot: appleProjectRoot,
              protocolScheme: protocolScheme,
            ));
  }

  AppleXcodeProjectSync _appleXcodeProjectSync() =>
      AppleXcodeProjectSync(generatedFileName: appleGeneratedFileName);

  AppleInfoPlistProtocolSync _appleInfoPlistProtocolSync() =>
      const AppleInfoPlistProtocolSync();

  String? _appleOpenAppProtocolScheme(final AgentManifest manifest) {
    final hasOpenAppTool = manifest.tools.any(
      (final tool) => tool.dispatchMode == AgentManifestDispatchMode.openApp,
    );
    if (!hasOpenAppTool) {
      return null;
    }
    final protocolScheme = manifest.protocolScheme?.trim();
    return protocolScheme == null || protocolScheme.isEmpty
        ? null
        : protocolScheme;
  }

  void _deleteStaleAppleGeneratedFiles(final Directory generatedDir) {
    for (final name in _staleAppleGeneratedFileNames()) {
      final file = File(p.join(generatedDir.path, name));
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  Iterable<String> _staleAppleGeneratedFileNames() sync* {
    const defaultGeneratedFileName = 'IntentCallGenerated.swift';
    if (appleGeneratedFileName != defaultGeneratedFileName) {
      yield defaultGeneratedFileName;
    }
  }

  File _androidShortcutsFile(final String projectRoot) => File(
    p.join(
      projectRoot,
      androidDirName,
      'app',
      'src',
      'main',
      'res',
      'xml',
      androidShortcutsFileName,
    ),
  );

  PlatformSyncResult _mergeResults(
    final PlatformSyncResult left,
    final PlatformSyncResult right,
  ) => PlatformSyncResult(
    manifestPath: left.manifestPath,
    dryRun: left.dryRun || right.dryRun,
    artifacts: <PlatformSyncArtifact>[...left.artifacts, ...right.artifacts],
    webManifestPath: right.webManifestPath ?? left.webManifestPath,
    webMcpJsPath: right.webMcpJsPath ?? left.webMcpJsPath,
    androidShortcutsPath:
        right.androidShortcutsPath ?? left.androidShortcutsPath,
    iosGeneratedSwiftPath:
        right.iosGeneratedSwiftPath ?? left.iosGeneratedSwiftPath,
    macosGeneratedSwiftPath:
        right.macosGeneratedSwiftPath ?? left.macosGeneratedSwiftPath,
    iosXcodeProjectPath: right.iosXcodeProjectPath ?? left.iosXcodeProjectPath,
    macosXcodeProjectPath:
        right.macosXcodeProjectPath ?? left.macosXcodeProjectPath,
    iosInfoPlistPath: right.iosInfoPlistPath ?? left.iosInfoPlistPath,
    macosInfoPlistPath: right.macosInfoPlistPath ?? left.macosInfoPlistPath,
    linuxDesktopPath: right.linuxDesktopPath ?? left.linuxDesktopPath,
    windowsProtocolPath: right.windowsProtocolPath ?? left.windowsProtocolPath,
    windowsMsixFragmentPath:
        right.windowsMsixFragmentPath ?? left.windowsMsixFragmentPath,
    wroteManifest: left.wroteManifest || right.wroteManifest,
    wroteWebMcpJs: left.wroteWebMcpJs || right.wroteWebMcpJs,
    wroteAndroidShortcuts:
        left.wroteAndroidShortcuts || right.wroteAndroidShortcuts,
    wroteIosGenerated: left.wroteIosGenerated || right.wroteIosGenerated,
    wroteMacosGenerated: left.wroteMacosGenerated || right.wroteMacosGenerated,
    wroteIosXcodeProject:
        left.wroteIosXcodeProject || right.wroteIosXcodeProject,
    wroteMacosXcodeProject:
        left.wroteMacosXcodeProject || right.wroteMacosXcodeProject,
    wroteIosInfoPlist: left.wroteIosInfoPlist || right.wroteIosInfoPlist,
    wroteMacosInfoPlist: left.wroteMacosInfoPlist || right.wroteMacosInfoPlist,
    wroteLinuxDesktop: left.wroteLinuxDesktop || right.wroteLinuxDesktop,
    wroteWindowsProtocol:
        left.wroteWindowsProtocol || right.wroteWindowsProtocol,
    wroteWindowsMsixFragment:
        left.wroteWindowsMsixFragment || right.wroteWindowsMsixFragment,
  );

  File _resolveManifestFile(final String projectRoot) {
    final rootCandidate = File(p.join(projectRoot, manifestFileName));
    if (rootCandidate.existsSync()) {
      return rootCandidate;
    }
    return File(p.join(projectRoot, webDirName, manifestFileName));
  }
}

/// Snippet to inject into `web/index.html` once.
const kIntentCallWebIndexSnippet = '''
<!-- intentcall-platform: begin -->
<script src="intentcall_webmcp.generated.js" defer></script>
<!-- intentcall-platform: end -->
''';
