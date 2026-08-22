import 'dart:async';
import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'acp_agent_backend.dart';
import 'acp_types.dart';

/// ACP backend that projects an [AgentRegistry] into the Agent Client
/// Protocol.
///
/// Prompt format (thin on purpose — ACP clients type free text):
///
/// ```text
/// contract_echo {"text": "hello", "count": 2}
/// ```
///
/// - First token is the registry qualified name (`namespace_name`).
/// - The remainder, when it parses as a JSON object, becomes the arguments.
/// - Otherwise the whole remainder is passed as `{'text': ...}`.
/// - A prompt with no arguments invokes with `{}`.
///
/// Results stream back as `session/update` notifications:
/// [ToolCallUpdate] while the intent runs, then [AgentMessageChunk] carrying
/// the [AgentResult] payload. Failures map to [AgentResult.failure] codes in
/// the streamed text plus a `refusal` stop reason.
final class RegistryAcpBackend implements AcpAgentBackend {
  RegistryAcpBackend({required this.registry, this.name = 'intentcall'});

  final AgentRegistry registry;

  @override
  final String name;

  @override
  String get version => '0.1.0';

  int _sessionCounter = 0;
  final Set<String> _sessions = <String>{};

  @override
  Map<String, Object?> get agentCapabilities => <String, Object?>{
    'promptCapabilities': <String, Object?>{'embeddedContext': false},
  };

  /// Advertises registered intents so clients can list the surface without
  /// invoking. Not part of the ACP baseline; exposed via `_meta` style data
  /// for harnesses and tests.
  List<Map<String, Object?>> listTools() => [
    for (final entry in registry.listEntries())
      if (entry.descriptor.kind == AgentIntentKind.tool)
        {
          'name': entry.key,
          'description': entry.descriptor.description,
          'inputSchema': entry.descriptor.inputSchema,
        },
  ];

  @override
  Future<String> createSession(final AcpSessionNewRequest request) async {
    _sessionCounter++;
    final sessionId = 'sess_intentcall_$_sessionCounter';
    _sessions.add(sessionId);
    return sessionId;
  }

  @override
  Future<AcpStopReason> prompt(
    final AcpPromptRequest request, {
    required final void Function(AcpSessionUpdate update) emit,
    required final bool Function() isCancelled,
  }) async {
    final text = request.prompt
        .whereType<AcpTextBlock>()
        .map((final block) => block.text)
        .join('\n')
        .trim();
    if (text.isEmpty) {
      emit(
        AgentMessageChunk(
          content: const AcpTextBlock('No prompt text provided.'),
        ),
      );
      return AcpStopReason.refusal;
    }

    final (qualifiedName, arguments) = _parsePrompt(text);
    final intent = registry.get(qualifiedName);
    if (intent == null || intent.descriptor.kind != AgentIntentKind.tool) {
      emit(
        AgentMessageChunk(
          content: AcpTextBlock(_unknownIntentText(qualifiedName)),
        ),
      );
      return AcpStopReason.refusal;
    }

    const toolCallId = 'call_registry_1';
    emit(
      ToolCallUpdate(
        toolCallId: toolCallId,
        title: qualifiedName,
        kind: 'other',
        status: 'in_progress',
      ),
    );

    final result = await registry.invoke(qualifiedName, arguments);

    if (isCancelled()) {
      emit(ToolCallUpdate(toolCallId: toolCallId, status: 'completed'));
      return AcpStopReason.cancelled;
    }

    emit(
      ToolCallUpdate(
        toolCallId: toolCallId,
        status: 'completed',
        content: [AcpTextBlock(_resultText(result))],
      ),
    );
    emit(AgentMessageChunk(content: AcpTextBlock(_resultText(result))));

    return result.ok ? AcpStopReason.endTurn : AcpStopReason.refusal;
  }

  @override
  Future<AcpPermissionOutcome> requestPermission(
    final AcpPermissionRequest request,
  ) async => AcpPermissionOutcome.allow;

  @override
  void cancelSession(final String sessionId) {}

  @override
  Future<void> disposeSession(final String sessionId) async {
    _sessions.remove(sessionId);
  }

  (String, Map<String, Object?>) _parsePrompt(final String text) {
    final firstSpace = text.indexOf(' ');
    if (firstSpace < 0) {
      return (text, const <String, Object?>{});
    }
    final name = text.substring(0, firstSpace).trim();
    final rest = text.substring(firstSpace + 1).trim();
    if (rest.isEmpty) {
      return (name, const <String, Object?>{});
    }
    try {
      final decoded = jsonDecode(rest);
      if (decoded is Map) {
        return (
          name,
          decoded.map<String, Object?>(
            (final key, final value) => MapEntry('$key', value),
          ),
        );
      }
    } on FormatException {
      // Fall through to plain-text argument shape.
    }
    return (name, <String, Object?>{'text': rest});
  }

  String _resultText(final AgentResult result) {
    if (!result.ok) {
      return jsonEncode(<String, Object?>{
        'ok': false,
        'code': result.code ?? 'agent_error',
        'message': result.message,
        'details': result.details,
      });
    }
    final text = result.data['text'];
    if (text is String && result.data.length == 1 && result.artifacts.isEmpty) {
      return text;
    }
    return jsonEncode(<String, Object?>{
      'ok': true,
      if (result.message.isNotEmpty) 'message': result.message,
      ...result.data,
    });
  }

  String _unknownIntentText(final String qualifiedName) {
    final available = listTools().map((final tool) => tool['name']).join(', ');
    return jsonEncode(<String, Object?>{
      'ok': false,
      'code': 'intent_not_found',
      'message':
          'No tool intent registered for $qualifiedName. '
          'Available: ${available.isEmpty ? '(none)' : available}',
    });
  }
}
