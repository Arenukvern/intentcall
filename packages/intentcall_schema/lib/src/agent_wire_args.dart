import 'package:from_json_to_json/from_json_to_json.dart';

import 'agent_result.dart';
import 'json_utils.dart';

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
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
  /// Returns `null` when the key is absent or the decoded value is not a map.
  Map<String, Object?>? jsonObject(final String key) {
    final raw = string(key);
    return jsonDecodeNullableMapAs<String, Object>(raw);
  }

  /// Copies the underlying map into [AgentArguments] (values remain strings).
  AgentArguments toAgentArguments() => Map<String, Object?>.from(_raw);
}
