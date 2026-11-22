import 'dart:convert';

/// Encodes one argument value for the service-extension wire.
///
/// Flutter's binding flattens extension parameters to `Map<String, String>`
/// via `toString()`, which turns maps and lists into Dart-syntax text the
/// far side cannot decode faithfully (see [tryDecodeDartLiteral] for the
/// lossy recovery path). Encoding complex values to JSON text BEFORE the
/// call keeps the round-trip exact: the flattening becomes a no-op for
/// them and `coerceArgumentsForSchema` decodes real JSON.
///
/// - `null` encodes to `''` (the extension-tier convention for "absent").
/// - Strings pass through unchanged (never double-encoded).
/// - Numbers and booleans use their literal text (`true`, `2.5`).
/// - Maps and lists become JSON text.
/// - Anything else falls back to `toString()` — the extension surfaces the
///   error honestly rather than throwing out of the encode step.
String wireValueForServiceExtension(final Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return '$value';
  }
  try {
    return jsonEncode(value);
  }
  // The error carries the unencodable value's explanation; the wire
  // contract degrades it to toString() text instead of failing the call.
  // ignore: avoid_catching_errors
  on JsonUnsupportedObjectError {
    return '$value';
  }
}

/// Encodes a whole argument map for the service-extension wire
/// (`Map<String, String>` — the shape Flutter's binding hands callbacks).
Map<String, String> wireArgumentsForServiceExtension(
  final Map<String, Object?> arguments,
) => arguments.map(
  (final key, final value) =>
      MapEntry(key, wireValueForServiceExtension(value)),
);
