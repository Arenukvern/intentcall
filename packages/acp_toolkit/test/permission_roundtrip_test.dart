import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

/// A backend that asks the client for permission mid-turn, then reports the
/// outcome — the harness write-gate pattern (ADR 0020 / N4).
class _GatedBackend implements AcpAgentBackend, AcpPermissionRequesting {
  Future<AcpPermissionOutcome> Function(AcpPermissionRequest)? _requester;
  AcpPermissionOutcome? outcome;

  @override
  void attachPermissionRequester(
    Future<AcpPermissionOutcome> Function(AcpPermissionRequest) requester,
  ) {
    _requester = requester;
  }

  @override
  String get name => 'gated';
  @override
  String get version => '0.0.1';
  @override
  Map<String, Object?> get agentCapabilities => const {};

  @override
  Future<String> createSession(AcpSessionNewRequest request) async => 's1';

  @override
  Future<AcpStopReason> prompt(
    AcpPromptRequest request, {
    required void Function(AcpSessionUpdate update) emit,
    required bool Function() isCancelled,
  }) async {
    outcome = await _requester!(
      const AcpPermissionRequest(
        sessionId: 's1',
        toolCallId: 'write-1',
        title: 'write main.dart',
        kind: 'edit',
      ),
    );
    emit(
      AgentMessageChunk(
        content: AcpTextBlock('outcome: ${outcome!.name}'),
      ),
    );
    return AcpStopReason.endTurn;
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

void main() {
  test('server routes backend permission requests to the client and back',
      () async {
    final fromClient = StreamController<List<int>>();
    final toClient = StreamController<Map<String, Object?>>();
    final backend = _GatedBackend();
    final server = AcpStdioServer(
      backend: backend,
      inputStream: fromClient.stream,
      outputSink: _Sink(toClient),
    );
    final done = server.run();

    final responses = <int, Map<String, Object?>>{};
    final collected = Completer<void>();
    late final StreamSubscription<Map<String, Object?>> sub;
    sub = toClient.stream.listen((msg) {
      if (msg.containsKey('id') && msg.containsKey('method')) {
        // A server→client CALL: answer it (the client's half of the
        // permission round-trip).
        final id = msg['id'];
        fromClient.add(
          utf8.encode(
            '${jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'outcome': {'optionId': 'allow', 'outcome': 'allow_once'},
              },
            })}\n',
          ),
        );
      } else if (msg.containsKey('id') && msg.containsKey('result')) {
        responses[msg['id'] as int] = msg['result'] as Map<String, Object?>;
        if (responses.length == 3 && !collected.isCompleted) {
          collected.complete();
        }
      }
    });

    fromClient.add(utf8.encode('${jsonEncode({
      'jsonrpc': '2.0',
      'id': 0,
      'method': 'initialize',
      'params': {'protocolVersion': 1},
    })}\n'));
    fromClient.add(utf8.encode('${jsonEncode({
      'jsonrpc': '2.0', 'id': 1, 'method': 'session/new', 'params': {'cwd': '/tmp'},
    })}\n'));
    fromClient.add(utf8.encode('${jsonEncode({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'session/prompt',
      'params': {'sessionId': 's1', 'prompt': [
        {'type': 'text', 'text': 'go'},
      ]},
    })}\n'));

    try {
      await collected.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      fail('responses: ${responses.keys.toList()} outcome: ${backend.outcome}');
    }
    expect(backend.outcome, AcpPermissionOutcome.allow);
    expect(responses[2]!['stopReason'], 'end_turn');
    sub.cancel();
    fromClient.close();
    done.ignore();
  });
}

final class _Sink implements StringSink {
  _Sink(this._sink);
  final StreamController<Map<String, Object?>> _sink;
  @override
  void write(Object? obj) {}
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {}
  @override
  void writeln([Object? obj = '']) {
    if (obj is String && obj.startsWith('{')) {
      _sink.add(Map<String, Object?>.from(jsonDecode(obj) as Map));
    }
  }
  @override
  void writeCharCode(int charCode) {}
}
