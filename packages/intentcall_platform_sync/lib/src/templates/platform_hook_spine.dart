import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Default CLI invocation when `intentcall.yaml` omits `hooks.syncCommand`.
const kDefaultHookCliInvocation = 'dart run intentcall_cli:intentcall';

/// Marker delimiters for generated host hook snippets.
const kPlatformHookMarkerBegin = 'intentcall-platform: begin';
const kPlatformHookMarkerEnd = 'intentcall-platform: end';

/// Legacy hook marker still accepted during migration.
const kLegacyFlutterMcpToolkitSyncMarker = 'flutter-mcp-toolkit codegen sync';

/// Current hook marker for [PlatformHooksInit] detection.
const kIntentcallPlatformSyncMarker = 'intentcall platform sync';

/// Host profile defaults for hook spine resolution (mirrors CLI [HostProfile]).
final class HookHostProfile {
  const HookHostProfile({
    required this.host,
    required this.defaultPlatforms,
    required this.hookTemplateKeys,
  });

  final String host;
  final List<String> defaultPlatforms;
  final List<String> hookTemplateKeys;
}

const kHookHostProfiles = <String, HookHostProfile>{
  'flutter': HookHostProfile(
    host: 'flutter',
    defaultPlatforms: <String>[
      'web',
      'android',
      'ios',
      'macos',
      'linux',
      'windows',
    ],
    hookTemplateKeys: <String>['android', 'ios', 'macos'],
  ),
  'jaspr': HookHostProfile(
    host: 'jaspr',
    defaultPlatforms: <String>['web'],
    hookTemplateKeys: <String>['jaspr'],
  ),
  'dart': HookHostProfile(
    host: 'dart',
    defaultPlatforms: <String>[],
    hookTemplateKeys: <String>[],
  ),
  'custom': HookHostProfile(
    host: 'custom',
    defaultPlatforms: <String>[],
    hookTemplateKeys: <String>[],
  ),
};

HookHostProfile hookHostProfileFor(final String hostName) {
  final normalized = _normalizeHostName(hostName);
  return kHookHostProfiles[normalized] ?? kHookHostProfiles['custom']!;
}

/// Inputs for [PlatformHookSpine.resolve].
final class PlatformHookSpineInput {
  const PlatformHookSpineInput({
    this.host = 'flutter',
    this.enabledPlatforms = const <String>[],
    this.syncCommand,
  });

  factory PlatformHookSpineInput.fromYamlMap(final YamlMap yaml) {
    final host = _normalizeHostName(yaml['host']?.toString());
    final enabled = <String>[];
    final platformsRaw = yaml['platforms'];
    if (platformsRaw is YamlMap) {
      final enabledRaw = platformsRaw['enabled'];
      if (enabledRaw is YamlList) {
        for (final value in enabledRaw) {
          final name = value?.toString().trim().toLowerCase();
          if (name != null && name.isNotEmpty) {
            enabled.add(name);
          }
        }
      }
    }
    String? syncCommand;
    final hooksRaw = yaml['hooks'];
    if (hooksRaw is YamlMap) {
      syncCommand = _nonEmpty(hooksRaw['syncCommand']?.toString());
    }
    return PlatformHookSpineInput(
      host: host,
      enabledPlatforms: enabled,
      syncCommand: syncCommand,
    );
  }

  final String host;
  final List<String> enabledPlatforms;
  final String? syncCommand;
}

/// One phase of the three-gate projection spine.
final class PlatformHookSpinePhase {
  const PlatformHookSpinePhase({
    required this.id,
    required this.argv,
    required this.shellLine,
  });

  final String id;
  final List<String> argv;
  final String shellLine;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'argv': argv,
    'shellLine': shellLine,
  };
}

/// Resolved hook spine: codegen → manifest export --check → platform sync.
final class PlatformHookSpine {
  const PlatformHookSpine({
    required this.host,
    required this.cliInvocation,
    required this.cliArgv,
    required this.platformList,
    required this.codegenPhase,
    required this.manifestPhase,
    required this.syncPhase,
    required this.hookTemplateKeys,
  });

  /// Resolves spine phases and platform list from [input].
  factory PlatformHookSpine.resolve(final PlatformHookSpineInput input) {
    final profile = hookHostProfileFor(input.host);
    final platforms = input.enabledPlatforms.isNotEmpty
        ? List<String>.from(input.enabledPlatforms)
        : List<String>.from(profile.defaultPlatforms);

    final cliInvocation = _nonEmpty(input.syncCommand) ?? kDefaultHookCliInvocation;
    final cliArgv = tokenizeShellCommand(cliInvocation);

    final codegenPhase = PlatformHookSpinePhase(
      id: 'codegen',
      argv: List<String>.from(codegenArgv),
      shellLine: _argvToShellLine(codegenArgv),
    );

    final manifestArgv = <String>[...cliArgv, 'manifest', 'export', '--check'];
    final manifestPhase = PlatformHookSpinePhase(
      id: 'manifest',
      argv: manifestArgv,
      shellLine: _argvToShellLine(manifestArgv),
    );

    final syncPlatforms = _syncPlatformsForHost(profile.host, platforms);
    final syncArgv = <String>[
      ...cliArgv,
      'platform',
      'sync',
      '--platform',
      syncPlatforms,
    ];
    final syncPhase = PlatformHookSpinePhase(
      id: 'sync',
      argv: syncArgv,
      shellLine: _argvToShellLine(syncArgv),
    );

    return PlatformHookSpine(
      host: profile.host,
      cliInvocation: cliInvocation,
      cliArgv: cliArgv,
      platformList: platforms,
      codegenPhase: codegenPhase,
      manifestPhase: manifestPhase,
      syncPhase: syncPhase,
      hookTemplateKeys: List<String>.from(profile.hookTemplateKeys),
    );
  }

  /// Loads `intentcall.yaml` from [projectRoot] and resolves the spine.
  factory PlatformHookSpine.resolveFromProjectRoot(final String projectRoot) {
    final root = p.normalize(p.absolute(projectRoot));
    final configFile = File(p.join(root, 'intentcall.yaml'));
    if (!configFile.existsSync()) {
      return PlatformHookSpine.resolve(const PlatformHookSpineInput());
    }
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is! YamlMap) {
      return PlatformHookSpine.resolve(const PlatformHookSpineInput());
    }
    return PlatformHookSpine.resolve(PlatformHookSpineInput.fromYamlMap(doc));
  }

  static const codegenArgv = <String>[
    'dart',
    'run',
    'build_runner',
    'build',
    '--delete-conflicting-outputs',
  ];

  final String host;
  final String cliInvocation;
  final List<String> cliArgv;
  final List<String> platformList;
  final PlatformHookSpinePhase codegenPhase;
  final PlatformHookSpinePhase manifestPhase;
  final PlatformHookSpinePhase syncPhase;
  final List<String> hookTemplateKeys;

  /// Renders a hook snippet for [templateKey] (`android`, `ios`, `macos`, `jaspr`, `web`).
  String renderTemplate(final String templateKey) {
    final key = templateKey.toLowerCase();
    return switch (key) {
      'android' => renderGradle(),
      'ios' || 'macos' => renderAppleXcode(),
      'jaspr' || 'web' => renderJasprWeb(),
      _ => throw ArgumentError('unknown hook template key "$templateKey"'),
    };
  }

  /// Gradle `preBuild` hook for Android.
  String renderGradle() {
    final androidPlatforms = _platformArg(
      platformList,
      preferred: const <String>['android'],
      fallback: 'android',
    );
    final syncArgv = <String>[
      ...cliArgv,
      'platform',
      'sync',
      '--platform',
      androidPlatforms,
    ];
    return '''
// $kPlatformHookMarkerBegin
tasks.named("preBuild").configure {
    doFirst {
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
${_gradleCommandLine(codegenArgv)}
            )
        }
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
${_gradleCommandLine(manifestPhase.argv)}
            )
        }
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
${_gradleCommandLine(syncArgv)}
            )
        }
    }
}
// $kPlatformHookMarkerEnd
''';
  }

  /// Xcode Run Script build phase for iOS/macOS.
  String renderAppleXcode() {
    final applePlatforms = _platformArg(
      platformList,
      preferred: const <String>['ios', 'macos'],
      fallback: 'ios,macos',
    );
    final syncLine = _argvToShellLine(<String>[
      ...cliArgv,
      'platform',
      'sync',
      '--platform',
      applePlatforms,
    ]);
    return '''
# $kPlatformHookMarkerBegin
cd "\${SRCROOT}/.."
${codegenPhase.shellLine}
${manifestPhase.shellLine}
$syncLine || exit 1
# $kPlatformHookMarkerEnd
''';
  }

  /// Jaspr / web-only hook snippet for CI or custom build steps.
  String renderJasprWeb() {
    final webPlatforms = _platformArg(
      platformList,
      preferred: const <String>['web'],
      fallback: 'web',
    );
    final syncLine = _argvToShellLine(<String>[
      ...cliArgv,
      'platform',
      'sync',
      '--platform',
      webPlatforms,
    ]);
    return '''
# $kPlatformHookMarkerBegin
${codegenPhase.shellLine}
${manifestPhase.shellLine}
$syncLine || exit 1
# $kPlatformHookMarkerEnd
''';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'host': host,
    'cliInvocation': cliInvocation,
    'cliArgv': cliArgv,
    'platformList': platformList,
    'hookTemplateKeys': hookTemplateKeys,
    'codegenPhase': codegenPhase.toJson(),
    'manifestPhase': manifestPhase.toJson(),
    'syncPhase': syncPhase.toJson(),
  };

  String encodeJson() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

String _normalizeHostName(final String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return 'custom';
  }
  return switch (trimmed) {
    'flutter' => 'flutter',
    'jaspr' => 'jaspr',
    'dart' => 'dart',
    _ => 'custom',
  };
}

String? _nonEmpty(final String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _syncPlatformsForHost(
  final String host,
  final List<String> platforms,
) {
  if (host == 'jaspr') {
    return _platformArg(platforms, preferred: const <String>['web'], fallback: 'web');
  }
  final mobile = platforms
      .where((final p) => <String>{'android', 'ios', 'macos', 'web'}.contains(p))
      .toList();
  if (mobile.isEmpty) {
    return platforms.join(',');
  }
  return mobile.join(',');
}

String _platformArg(
  final List<String> platforms, {
  required final List<String> preferred,
  required final String fallback,
}) {
  final selected = preferred.where(platforms.contains).toList();
  if (selected.isEmpty) {
    return fallback;
  }
  return selected.join(',');
}

String _argvToShellLine(final List<String> argv) => argv.join(' ');

String _gradleCommandLine(final List<String> argv) {
  final lines = argv.map((final arg) => '                "$arg"');
  return lines.join(',\n');
}

/// Tokenizes a shell command string into argv (supports simple quotes).
List<String> tokenizeShellCommand(final String command) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;

  for (var i = 0; i < command.length; i++) {
    final ch = command[i];
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else {
        buffer.write(ch);
      }
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
      continue;
    }
    if (ch.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    buffer.write(ch);
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }
  return tokens;
}
