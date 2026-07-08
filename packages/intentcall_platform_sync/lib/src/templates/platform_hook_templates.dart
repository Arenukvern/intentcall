import 'platform_hook_spine.dart';

export 'platform_hook_spine.dart';

/// Default Flutter hook spine (no project `intentcall.yaml`).
PlatformHookSpine get kDefaultFlutterHookSpine =>
    PlatformHookSpine.resolve(const PlatformHookSpineInput(host: 'flutter'));

/// Default Jaspr hook spine (no project `intentcall.yaml`).
PlatformHookSpine get kDefaultJasprHookSpine =>
    PlatformHookSpine.resolve(const PlatformHookSpineInput(host: 'jaspr'));

/// Gradle `preBuild` hook — inject into `android/app/build.gradle.kts` once.
String get kAndroidGradleCodegenHook => kDefaultFlutterHookSpine.renderGradle();

/// Xcode Run Script build phase — add to iOS/macOS target once.
String get kAppleXcodeCodegenRunScript =>
    kDefaultFlutterHookSpine.renderAppleXcode();

/// Jaspr / web-only hook snippet for CI or custom build steps.
String get kJasprWebCodegenHook => kDefaultJasprHookSpine.renderJasprWeb();

/// Documents where hook templates live for `init intentcall-platform`.
const kPlatformHookTemplatePaths = <String, String>{
  'android': 'intentcall_platform Gradle hook (kAndroidGradleCodegenHook)',
  'ios': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'macos': 'intentcall_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'jaspr': 'intentcall_platform web hook (kJasprWebCodegenHook)',
};
