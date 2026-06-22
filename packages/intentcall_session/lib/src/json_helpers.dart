// Copyright (c) 2025, IntentCall authors.
// Licensed under the MIT License.

import 'package:from_json_to_json/from_json_to_json.dart';

Map<String, Object?> jsonObjectOrEmpty(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  try {
    return Map<String, Object?>.from(jsonDecodeMap(value));
  } on Exception {
    return const <String, Object?>{};
  }
}
