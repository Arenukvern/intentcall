import 'dart:convert';

import 'agent_result.dart';

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
  bool? bool_(final String key) {
    final normalized = string(key)?.toLowerCase();
    if (normalized == null) {
      return null;
    }
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
      return true;
    }
    if (normalized == '0' || normalized == 'false' || normalized == 'no') {
      return false;
    }
    return null;
  }

  /// Parses an integer from the string value, or `null` if missing or invalid.
  int? int_(final String key) => int.tryParse(_raw[key]?.trim() ?? '');

  /// Parses a double from the string value, or `null` if missing or invalid.
  double? double_(final String key) => double.tryParse(_raw[key]?.trim() ?? '');

  /// Decodes a JSON object from the string value at [key].
  ///
  /// Returns `null` when the key is absent or the decoded value is not a map.
  Map<String, Object?>? jsonObject(final String key) {
    final raw = string(key);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return null;
  }

  /// Copies the underlying map into [AgentArguments] (values remain strings).
  AgentArguments toAgentArguments() => Map<String, Object?>.from(_raw);
}
