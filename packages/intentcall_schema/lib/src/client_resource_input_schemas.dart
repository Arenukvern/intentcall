// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'agent_result.dart';

/// Extracts an [InputSchema] from a dynamic resource registration map.
///
/// Reads `inputSchema` from [registration]. When absent, returns
/// [clientResourceReadInputSchema] (URI-only read args for
/// `fmt_client_resource` style resources).
///
/// Throws [ArgumentError] when `inputSchema` is present but not a `Map`.
InputSchema inputSchemaFromDynamicRegistrationMap(
  final Map<String, Object?> registration,
) {
  final raw = registration['inputSchema'];
  if (raw == null) {
    return clientResourceReadInputSchema();
  }
  if (raw is! Map) {
    throw ArgumentError('Resource registration inputSchema must be a Map');
  }
  return _deepCopySchemaMap(Map<Object?, Object?>.from(raw));
}

/// Default JSON Schema for reading a dynamic client resource by URI.
///
/// Requires a single `uri` string property. Used when a resource registration
/// does not supply a custom `inputSchema`.
InputSchema clientResourceReadInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['uri'],
  'properties': <String, Object?>{
    'uri': <String, Object?>{
      'type': 'string',
      'description': 'Resource URI to read.',
    },
  },
};

/// Default JSON Schema for reading a dynamic client resource template.
///
/// Always requires `uri`. Additional [templateVariables] (for example `count`)
/// are added to `properties`; `count` is typed as `integer`, others as
/// `string`. Skips a variable named `uri` if listed twice.
InputSchema clientResourceTemplateReadInputSchema({
  final Iterable<String> templateVariables = const <String>['count'],
}) {
  final properties = <String, Object?>{
    'uri': <String, Object?>{
      'type': 'string',
      'description': 'Concrete resource URI matching the template.',
    },
  };
  for (final variable in templateVariables) {
    if (variable == 'uri') {
      continue;
    }
    properties[variable] = <String, Object?>{
      'type': variable == 'count' ? 'integer' : 'string',
    };
  }
  return <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'required': <String>['uri'],
    'properties': properties,
  };
}

InputSchema _deepCopySchemaMap(final Map<Object?, Object?> raw) => raw.map(
  (final key, final value) =>
      MapEntry(key.toString(), _normalizeSchemaValue(value)),
);

Object? _normalizeSchemaValue(final Object? value) {
  if (value is Map) {
    return _deepCopySchemaMap(Map<Object?, Object?>.from(value));
  }
  if (value is Iterable && value is! String) {
    return value
        .map<Object?>(
          (final item) => item is Map
              ? _deepCopySchemaMap(Map<Object?, Object?>.from(item))
              : item,
        )
        .toList();
  }
  return value;
}
