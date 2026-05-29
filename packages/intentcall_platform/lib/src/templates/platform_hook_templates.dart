/// Gradle `preBuild` hook — inject into `android/app/build.gradle.kts` once.
const kAndroidGradleCodegenHook = '''
// intentcall-platform: begin
tasks.named("preBuild").configure {
    doFirst {
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
                "flutter-mcp-toolkit",
                "codegen",
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
flutter-mcp-toolkit codegen sync --platform ios,macos || exit 1
# intentcall-platform: end
''';

/// Documents where hook templates live for `init intentcall-platform`.
const kPlatformHookTemplatePaths = <String, String>{
  'android': 'intentcall_platform Gradle hook (kAndroidGradleCodegenHook)',
  'ios': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'macos': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
};
