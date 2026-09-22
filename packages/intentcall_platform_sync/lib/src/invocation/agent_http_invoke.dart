import 'dart:convert';

import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_surface_link.dart';
import 'intentcall_invocation.dart';

/// HTTP invoke for a page whose browser has no WebMCP.
///
/// This is the channel between a CLI-launched server and the website GUI.
/// The generated page script posts here when `document.modelContext` is
/// absent or the in-page Dart runtime is not registered:
/// `POST /agent/invoke?name=<qualifiedName>` with a JSON argument body.
///
/// The coding agent does not call this route. It uses the Dart MCP adapter
/// in `intentcall_mcp` against the same [AgentRegistry]. WebMCP, when the
/// browser has it, is an extra projection of that registry, not a second one.
final class AgentHttpInvoke {
  const AgentHttpInvoke({required this.bridge}) : link = null;

  const AgentHttpInvoke.through(this.link) : bridge = null;

  static const String defaultPath = '/agent/invoke';

  final IntentCallNativeBridge? bridge;
  final AgentSurfaceLink? link;

  Future<Map<String, Object?>> handle({
    required final Uri requestUri,
    required final String body,
  }) async {
    final qualifiedName = requestUri.queryParameters['name']?.trim() ?? '';
    if (qualifiedName.isEmpty) {
      return _payload(
        AgentResult.failure(
          code: 'invalid_request',
          message: 'Missing tool name. POST $defaultPath?name=<qualifiedName>.',
        ),
      );
    }
    final arguments = _decodeArguments(body);
    if (arguments == null) {
      return _payload(
        AgentResult.failure(
          code: 'invalid_request',
          message: 'Tool arguments must be a JSON object.',
        ),
      );
    }
    final envelope = IntentCallInvocationEnvelope(
      id: 'http-invoke-${DateTime.now().microsecondsSinceEpoch}',
      qualifiedName: qualifiedName,
      arguments: arguments,
      source: IntentCallInvocationSource.webMcpFallback,
    );
    final surface = link;
    final direct = bridge;
    final result = surface == null
        ? await direct!.execute(envelope)
        : await surface.invoke(envelope);
    return _payload(result);
  }
}

Map<String, Object?>? _decodeArguments(final String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return const <String, Object?>{};
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((final key, final value) => MapEntry('$key', value));
  }
  return null;
}

Map<String, Object?> _payload(final AgentResult result) {
  if (!result.ok) {
    return <String, Object?>{
      'ok': false,
      'code': result.code,
      'message': result.message,
      if (result.details.isNotEmpty) 'details': result.details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}
