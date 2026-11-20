import 'package:from_json_to_json/from_json_to_json.dart';

import 'agent_result.dart';

/// validates every key is String, and checs map values
/// normalization?
Map<String, Object?> jsonDecodeNullableStringKeyMap(
  final Map<String, Object?> value,
) => Map<String, Object?>.unmodifiable(
  value.map((final key, final value) => MapEntry(key, _jsonValue(value))),
);

Object? _jsonValue(final Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Expected a finite number.');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_jsonValue));
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((final key, final value) {
        if (key is! String) {
          throw ArgumentError.value(key, 'key', 'Expected a string key.');
        }
        return MapEntry(key, _jsonValue(value));
      }),
    );
  }
  throw ArgumentError.value(value, 'value', 'Expected a JSON-safe value.');
}

InputSchema deepCopySchemaMap(final Map<Object?, Object?> raw) => raw.map(
  (final key, final value) =>
      MapEntry(key.toString(), _normalizeSchemaValue(value)),
);

Object? _normalizeSchemaValue(final Object? value) {
  if (value is Map) {
    return deepCopySchemaMap(Map<Object?, Object?>.from(value));
  }
  if (value is Iterable && value is! String) {
    return value
        .map<Object?>(
          (final item) => item is Map
              ? deepCopySchemaMap(Map<Object?, Object?>.from(item))
              : item,
        )
        .toList();
  }
  return value;
}
