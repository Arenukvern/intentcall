import 'intentcall_config.dart';

/// Default enabled platforms per host profile when `intentcall.yaml` omits them.
final class HostProfile {
  const HostProfile({
    required this.host,
    required this.defaultPlatforms,
    required this.hookTemplateKeys,
  });

  final IntentCallHost host;
  final List<String> defaultPlatforms;
  final List<String> hookTemplateKeys;
}

const kHostProfiles = <IntentCallHost, HostProfile>{
  IntentCallHost.flutter: HostProfile(
    host: IntentCallHost.flutter,
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
  IntentCallHost.jaspr: HostProfile(
    host: IntentCallHost.jaspr,
    defaultPlatforms: <String>['web'],
    hookTemplateKeys: <String>['jaspr'],
  ),
  IntentCallHost.dart: HostProfile(
    host: IntentCallHost.dart,
    defaultPlatforms: <String>[],
    hookTemplateKeys: <String>[],
  ),
  IntentCallHost.custom: HostProfile(
    host: IntentCallHost.custom,
    defaultPlatforms: <String>[],
    hookTemplateKeys: <String>[],
  ),
};

HostProfile hostProfileFor(final IntentCallConfig config) =>
    kHostProfiles[config.host] ?? kHostProfiles[IntentCallHost.custom]!;

/// Resolves enabled platforms from config, falling back to host defaults.
List<String> resolveEnabledPlatforms(final IntentCallConfig config) {
  if (config.platforms.enabled.isNotEmpty) {
    return List<String>.from(config.platforms.enabled);
  }
  return List<String>.from(hostProfileFor(config).defaultPlatforms);
}

String normalizeHostName(final String? value) {
  final host = tryParseIntentCallHost(value);
  return host?.name ?? IntentCallHost.custom.name;
}
