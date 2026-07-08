import 'dart:io';

import 'package:path/path.dart' as p;

import '../emitters/android_shortcuts_xml_emitter.dart';
import '../sync/platform_sync.dart';
import '../templates/platform_hook_spine.dart';
import '../templates/platform_hook_templates.dart';

const _markerBegin = 'intentcall-platform: begin';
const _markerEnd = 'intentcall-platform: end';

/// Result of applying or checking one hook target file.
final class PlatformHookTargetResult {
  const PlatformHookTargetResult({
    required this.id,
    required this.path,
    required this.ok,
    this.message,
  });

  final String id;
  final String path;
  final bool ok;
  final String? message;
}

/// Summary of [PlatformHooksInit.run].
final class PlatformHooksInitReport {
  const PlatformHooksInitReport({
    required this.projectRoot,
    required this.checkOnly,
    required this.targets,
  });

  final String projectRoot;
  final bool checkOnly;
  final List<PlatformHookTargetResult> targets;

  bool get ok => targets.every((final t) => t.ok);
}

/// Idempotent one-time hooks for Flutter projects (`init intentcall-platform`).
final class PlatformHooksInit {
  const PlatformHooksInit();

  Future<PlatformHooksInitReport> run({
    required final String projectRoot,
    final bool checkOnly = false,
  }) async {
    final root = p.normalize(p.absolute(projectRoot));
    final spine = PlatformHookSpine.resolveFromProjectRoot(root);
    final enabled = spine.platformList.toSet();
    // Host template keys (android/ios/macos/…) ∩ enabled, plus web when enabled.
    final patchable = enabled.intersection(spine.hookTemplateKeys.toSet());
    if (enabled.contains('web')) {
      patchable.add('web');
    }

    final targets = <PlatformHookTargetResult>[];
    if (patchable.contains('web')) {
      targets.add(
        await _patchFile(
          id: 'web_index_html',
          path: p.join(root, 'web', 'index.html'),
          snippet: kIntentCallWebIndexSnippet.trim(),
          checkOnly: checkOnly,
        ),
      );
    }
    if (patchable.contains('android')) {
      targets.add(
        await _patchFile(
          id: 'android_gradle',
          path: p.join(root, 'android', 'app', 'build.gradle.kts'),
          snippet: spine.renderGradle().trim(),
          checkOnly: checkOnly,
          appendIfMissing: true,
        ),
      );
      targets.add(
        await _patchFile(
          id: 'android_manifest',
          path: p.join(
            root,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
          snippet: kAndroidShortcutsManifestSnippet.trim(),
          checkOnly: checkOnly,
          insertBefore: '</application>',
        ),
      );
    }
    if (patchable.contains('ios')) {
      targets.add(
        await _patchFile(
          id: 'ios_codegen_script',
          path: p.join(root, 'ios', 'intentcall_codegen.sh'),
          snippet: spine.renderAppleXcode().trim(),
          checkOnly: checkOnly,
          wholeFile: true,
        ),
      );
      targets.add(
        _checkXcodeRunScript(
          id: 'ios_xcode_run_script',
          path: p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        ),
      );
    }
    if (patchable.contains('macos')) {
      targets.add(
        await _patchFile(
          id: 'macos_codegen_script',
          path: p.join(root, 'macos', 'intentcall_codegen.sh'),
          snippet: spine.renderAppleXcode().trim(),
          checkOnly: checkOnly,
          wholeFile: true,
        ),
      );
      targets.add(
        _checkXcodeRunScript(
          id: 'macos_xcode_run_script',
          path: p.join(root, 'macos', 'Runner.xcodeproj', 'project.pbxproj'),
        ),
      );
    }

    return PlatformHooksInitReport(
      projectRoot: root,
      checkOnly: checkOnly,
      targets: targets,
    );
  }

  PlatformHookTargetResult _checkXcodeRunScript({
    required final String id,
    required final String path,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      return PlatformHookTargetResult(
        id: id,
        path: path,
        ok: false,
        message:
            'Missing Xcode project — add Run Script manually (see INTENTCALL_PLATFORM.md)',
      );
    }
    final scriptPath = p.join(
      p.dirname(p.dirname(path)),
      'intentcall_codegen.sh',
    );
    final scriptOk = File(scriptPath).existsSync();
    final content = file.readAsStringSync();
    final ok =
        scriptOk ||
        (content.contains(_markerBegin) &&
            (content.contains(kIntentcallPlatformSyncMarker) ||
                content.contains(kLegacyFlutterMcpToolkitSyncMarker)));
    return PlatformHookTargetResult(
      id: id,
      path: path,
      ok: ok,
      message: ok
          ? null
          : r'Add Xcode Run Script: bash "$SRCROOT/intentcall_codegen.sh" '
                '(see INTENTCALL_PLATFORM.md)',
    );
  }

  Future<PlatformHookTargetResult> _patchFile({
    required final String id,
    required final String path,
    required final String snippet,
    required final bool checkOnly,
    final bool appendIfMissing = false,
    final String? insertBefore,
    final bool wholeFile = false,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      if (wholeFile) {
        if (checkOnly) {
          return PlatformHookTargetResult(
            id: id,
            path: path,
            ok: false,
            message: 'Codegen shell script missing',
          );
        }
        await file.parent.create(recursive: true);
        await file.writeAsString('$snippet\n');
        return PlatformHookTargetResult(id: id, path: path, ok: true);
      }
      return PlatformHookTargetResult(
        id: id,
        path: path,
        ok: false,
        message: 'File not found',
      );
    }

    final original = await file.readAsString();
    if (wholeFile) {
      final ok = original == '$snippet\n' || original == snippet;
      if (checkOnly) {
        return PlatformHookTargetResult(
          id: id,
          path: path,
          ok: ok,
          message: ok ? null : 'Codegen shell script drift',
        );
      }
      if (!ok) {
        await file.writeAsString('$snippet\n');
      }
      return PlatformHookTargetResult(id: id, path: path, ok: true);
    }

    if (original.contains(_markerBegin) && original.contains(_markerEnd)) {
      return PlatformHookTargetResult(id: id, path: path, ok: true);
    }

    if (checkOnly) {
      return PlatformHookTargetResult(
        id: id,
        path: path,
        ok: false,
        message: 'Missing $_markerBegin … $_markerEnd block',
      );
    }

    String updated;
    if (insertBefore != null && original.contains(insertBefore)) {
      updated = original.replaceFirst(insertBefore, '$snippet\n$insertBefore');
    } else if (appendIfMissing) {
      updated = '${original.trimRight()}\n\n$snippet\n';
    } else {
      updated = '$original\n$snippet\n';
    }
    await file.writeAsString(updated);
    return PlatformHookTargetResult(id: id, path: path, ok: true);
  }
}
