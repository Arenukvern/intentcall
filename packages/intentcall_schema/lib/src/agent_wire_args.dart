import 'package:from_json_to_json/from_json_to_json.dart';

import 'agent_result.dart';
import 'dart_literal.dart';

/// Typed view over a VM service extension wire map (`Map<String, String>`).
///
/// Service extensions and some debug bridges deliver all values as strings.
/// Use the typed accessors to parse common shapes, then
/// [toAgentArguments] before [coerceArgumentsForSchema].
///
/// ```dart
/// final wire = AgentWireArgs({'count': '3', 'enabled': 'true'});
/// wire.int_('count'); // 3
/// wire.bool_('enabled'); // true
/// ```
extension type const AgentWireArgs(AgentWireMap _raw) {
  /// Returns a trimmed non-empty string, or `null` if missing or blank.
  String? string(final String key) {
    // TODO: migrate to from_json_to_json jsonDecodeNullableString
    final value = _raw[key];
    return jsonDecodeNullableNotEmptyString(value?.trim());
  }

  /// Parses common wire boolean literals: `1`/`0`, `true`/`false`, `yes`/`no`.
  ///
  /// Returns `null` when the key is absent or the value is not recognized.
  bool? bool_(final String key) => jsonDecodeNullableBool(string(key));

  /// Parses an integer from the string value, or `null` if missing or invalid.
  int? int_(final String key) => jsonDecodeNullableInt(_raw[key]?.trim());

  /// Parses a double from the string value, or `null` if missing or invalid.
  double? double_(final String key) =>
      jsonDecodeNullableDouble(_raw[key]?.trim());

  /// Decodes a JSON object from the string value at [key].
  ///
  /// Dart `toString()` syntax (the service-extension flattening) is
  /// recovered with [tryDecodeDartMap]. Returns `null` when the key is
  /// absent or the value decodes to neither JSON object nor Dart map.
  Map<String, Object?>? jsonObject(final String key) {
    final raw = string(key);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecodeNullableMapAs<String, Object>(raw);
      if (decoded != null) {
        return decoded;
      }
    } on FormatException {
      // Fall through to the Dart-literal recovery.
    }
    return tryDecodeDartMap(raw);
  }

  /// Copies the underlying map into [AgentArguments] (values remain strings).
  AgentArguments toAgentArguments() => Map<String, Object?>.from(_raw);
}
