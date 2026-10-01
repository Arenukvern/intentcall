// Copyright (c) 2025, IntentCall authors.
// Licensed under the MIT License.

import 'package:from_json_to_json/from_json_to_json.dart';

Map<String, Object?> jsonDecodeObjectOrEmpty(final Object? value) =>
    jsonDecodeMapAs(value);

// TODO(arenukvern): migrate to from_json_to_json
String? jsonDecodeNullableString(final Object? value) {
  if (value == null) {
    return null;
  }
  return jsonDecodeString(value);
}
