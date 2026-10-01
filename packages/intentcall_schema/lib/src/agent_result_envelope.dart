import 'dart:convert';

import 'agent_result.dart';
import 'resource_uri.dart';

/// Builders for versioned snapshot payloads inside [AgentResult] data maps.
///
/// Envelopes follow an ecsly-style shape so MCP resources, inspector tools, and
/// codegen fixtures can share one JSON contract. Agents should read
/// `schema_version`, `kind`, and `snapshot` (or `snapshot_json`) from the
/// result data map.
extension AgentResultEnvelope on AgentResult {
  /// Creates a success result wrapping a versioned [snapshot].
  ///
  /// [kind] identifies the tool or snapshot type (also stored as `tool_name`).
  /// [extra] merges additional JSON-safe fields into the result data map.
  ///
  /// ```dart
  /// AgentResultEnvelope.envelope(
  ///   kind: 'widget_tree',
  ///   snapshot: {'root': 'MaterialApp'},
  /// );
  /// ```
  static AgentResult envelope({
    required final String kind,
    required final Map<String, Object?> snapshot,
    final String message = 'ok',
    final int schemaVersion = 1,
    final Map<String, Object?>? extra,
  }) => AgentResult.success(
    message: message,
    data: {
      'schema_version': schemaVersion,
      'kind': kind,
      'tool_name': kind,
      'snapshot': snapshot,
      'snapshot_json': jsonEncode(snapshot),
      ...?extra,
    },
  );

  /// Creates a success result for a named MCP-style resource snapshot.
  ///
  /// Populates `resource_uri`, `resource`, and `contents` so clients can treat
  /// the payload like a resource read response. [resourceName] uses underscore
  /// segments that map to path segments in the URI (see [resourceUri]).
  static AgentResult resourceEnvelope({
    required final String protocolScheme,
    required final String resourceName,
    required final Map<String, Object?> snapshot,
    final String mimeType = 'application/json',
    final int schemaVersion = 1,
  }) {
    final uri = resourceUri(
      protocolScheme: protocolScheme,
      resourceName: resourceName,
    );
    final text = jsonEncode(snapshot);
    final resource = <String, Object?>{
      'uri': uri,
      'mimeType': mimeType,
      'text': text,
    };
    return AgentResult.success(
      message: '$resourceName snapshot.',
      data: {
        'schema_version': schemaVersion,
        'kind': resourceName,
        'resource_name': resourceName,
        'resource_uri': uri,
        'mimeType': mimeType,
        'snapshot': snapshot,
        'snapshot_json': text,
        'resource': resource,
        'contents': <Map<String, Object?>>[resource],
      },
    );
  }
}
