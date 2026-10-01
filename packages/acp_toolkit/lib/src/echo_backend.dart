import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';

/// Minimal ACP agent backend that echoes prompts back.
///
/// Useful as a conformance smoke target and as a template for real backends
/// (e.g. one driving `AppleFoundationNativeClient` over FFI).
final class EchoAcpBackend implements AcpAgentBackend {
  EchoAcpBackend({this.delay = Duration.zero});

  /// Artificial per-chunk delay to exercise streaming.
  final Duration delay;

  int _sessionCounter = 0;

  @override
  String get name => 'echo-agent';

  @override
  String get version => '0.1.0';

  @override
  Map<String, Object?> get agentCapabilities => <String, Object?>{
    'promptCapabilities': <String, Object?>{'embeddedContext': false},
  };

  @override
  Future<String> createSession(AcpSessionNewRequest request) async {
    _sessionCounter++;
    return 'sess_echo_$_sessionCounter';
  }

  @override
  Future<AcpStopReason> prompt(
    AcpPromptRequest request, {
    required void Function(AcpSessionUpdate update) emit,
    required bool Function() isCancelled,
  }) async {
    final text = request.prompt
        .whereType<AcpTextBlock>()
        .map((b) => b.text)
        .join('\n');

    // Emit a plan, then stream the echo in word chunks.
    emit(
      Plan(
        entries: [
          const PlanEntry(content: 'Echo the user message', priority: 'high'),
        ],
      ),
    );

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var toolCallId = '';
    if (words.isNotEmpty) {
      toolCallId = 'call_echo_1';
      emit(
        ToolCallUpdate(
          toolCallId: toolCallId,
          title: 'Echoing message',
          kind: 'other',
          status: 'in_progress',
        ),
      );
    }

    final buffer = StringBuffer();
    for (final word in words) {
      if (isCancelled()) return AcpStopReason.cancelled;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      buffer.write('$word ');
      emit(
        AgentMessageChunk(
          content: AcpTextBlock('$word '),
          messageId: 'msg_echo',
        ),
      );
    }

    if (toolCallId.isNotEmpty) {
      emit(
        ToolCallUpdate(
          toolCallId: toolCallId,
          status: 'completed',
          content: [AcpTextBlock(buffer.toString().trim())],
        ),
      );
    }

    return isCancelled() ? AcpStopReason.cancelled : AcpStopReason.endTurn;
  }

  @override
  Future<AcpPermissionOutcome> requestPermission(
    AcpPermissionRequest request,
  ) async => AcpPermissionOutcome.allow;

  @override
  void cancelSession(String sessionId) {}

  @override
  Future<void> disposeSession(String sessionId) async {}
}

/// Convenience: run an [EchoAcpBackend] over stdio until stdin closes.
Future<void> runEchoServer() async {
  final server = AcpStdioServer(backend: EchoAcpBackend());
  await server.run();
}

/// Encodes a single JSON-RPC request line (test helper).
String rpcRequest(int id, String method, Map<String, Object?> params) =>
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

/// Encodes a single JSON-RPC notification line (test helper).
String rpcNotify(String method, Map<String, Object?> params) =>
    jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params});
