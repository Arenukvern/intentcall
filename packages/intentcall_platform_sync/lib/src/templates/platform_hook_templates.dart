/// Gradle `preBuild` hook — inject into `android/app/build.gradle.kts` once.
const kAndroidGradleCodegenHook = '''
// intentcall-platform: begin
tasks.named("preBuild").configure {
    doFirst {
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
                "dart",
                "run",
                "build_runner",
                "build",
                "--delete-conflicting-outputs",
            )
        }
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
                "intentcall",
                "manifest",
                "export",
                "--check",
            )
        }
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
                "intentcall",
                "platform",
                "sync",
                "--platform",
                "android",
            )
        }
    }
}
// intentcall-platform: end
''';

/// Xcode Run Script build phase — add to iOS/macOS target once.
const kAppleXcodeCodegenRunScript = r'''
# intentcall-platform: begin
cd "${SRCROOT}/.."
dart run build_runner build --delete-conflicting-outputs
intentcall manifest export --check
intentcall platform sync --platform ios,macos || exit 1
# intentcall-platform: end
''';

/// Jaspr / web-only hook snippet for CI or custom build steps.
const kJasprWebCodegenHook = '''
# intentcall-platform: begin
dart run build_runner build --delete-conflicting-outputs
intentcall manifest export --check
intentcall platform sync --platform web || exit 1
# intentcall-platform: end
''';

/// Documents where hook templates live for `init intentcall-platform`.
const kPlatformHookTemplatePaths = <String, String>{
  'android': 'intentcall_platform Gradle hook (kAndroidGradleCodegenHook)',
  'ios': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'macos': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'jaspr': 'intentcall_platform web hook (kJasprWebCodegenHook)',
};

/// Legacy hook marker still accepted during migration.
const kLegacyFlutterMcpToolkitSyncMarker = 'flutter-mcp-toolkit codegen sync';

/// Current hook marker for [PlatformHooksInit] detection.
const kIntentcallPlatformSyncMarker = 'intentcall platform sync';
