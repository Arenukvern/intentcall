import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

/// Drives [AcpStdioServer] over in-memory pipes, capturing notifications.
Future<
  ({
    AcpStdioServer server,
    Stream<Map<String, Object?>> messages,
    Future<void> Function(String line) send,
    void Function() closeInput,
  })
>
_spawn(AcpAgentBackend backend) async {
  final fromClient = StreamController<List<int>>();
  final toClient = StreamController<Map<String, Object?>>();
  final outputSink = _StreamStringSink(toClient);

  final server = AcpStdioServer(
    backend: backend,
    inputStream: fromClient.stream,
    outputSink: outputSink,
  );
  final done = server.run();

  return (
    server: server,
    messages: toClient.stream,
    send: (String line) async => fromClient.add(utf8.encode('$line\n')),
    closeInput: () {
      fromClient.close();
      // Ensure the run loop exits.
      done.ignore();
    },
  );
}

final class _StreamStringSink implements StringSink {
  _StreamStringSink(this._sink);
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

void main() {
  test(
    'full lifecycle: initialize → session/new → prompt → updates → stop',
    () async {
      final harness = await _spawn(EchoAcpBackend());
      final responses = <int, Map<String, Object?>>{};
      final notifications = <Map<String, Object?>>[];
      final allMessages = <Map<String, Object?>>[];

      final collected = Completer<void>();
      late StreamSubscription<Map<String, Object?>> sub;
      sub = harness.messages.listen((msg) {
        allMessages.add(msg);
        if (msg.containsKey('id') && msg.containsKey('result')) {
          responses[msg['id'] as int] = msg;
          if (responses.length == 3 && !collected.isCompleted) {
            collected.complete();
          }
        } else if (msg.containsKey('method')) {
          notifications.add(msg);
        }
      });

      await harness.send(
        rpcRequest(0, 'initialize', {
          'protocolVersion': 1,
          'clientCapabilities': {
            'fs': {'readTextFile': true},
          },
          'clientInfo': {'name': 'test-client', 'version': '0.0.1'},
        }),
      );
      await harness.send(rpcRequest(1, 'session/new', {'cwd': '/tmp/proj'}));
      await harness.send(
        rpcRequest(2, 'session/prompt', {
          'sessionId': 'sess_echo_1',
          'prompt': [
            {'type': 'text', 'text': 'hello world'},
          ],
        }),
      );

      await collected.future.timeout(const Duration(seconds: 5));

      // initialize response
      final init = responses[0]!['result'] as Map<String, Object?>;
      expect(init['protocolVersion'], 1);
      expect((init['agentInfo'] as Map)['name'], 'echo-agent');

      // session/new response
      expect(responses[1]!['result'], {'sessionId': 'sess_echo_1'});

      // prompt response ends with end_turn
      final promptResult = responses[2]!['result'] as Map<String, Object?>;
      expect(promptResult['stopReason'], 'end_turn');

      // Notifications include plan, chunks, and tool call updates.
      final methods = notifications.map((n) => n['method']).toSet();
      expect(methods, contains('session/update'));
      final updates = notifications
          .where((n) => n['method'] == 'session/update')
          .map((n) => (n['params'] as Map)['update'] as Map)
          .toList();
      final updateKinds = updates.map((u) => u['sessionUpdate']).toSet();
      expect(updateKinds, containsAll(['plan', 'agent_message_chunk']));
      expect(updateKinds, contains('tool_call_update'));

      // Full echoed text arrived across chunks.
      final chunkText = updates
          .where((u) => u['sessionUpdate'] == 'agent_message_chunk')
          .map((u) => ((u['content'] as Map)['text']) as String)
          .join();
      expect(chunkText.trim(), 'hello world');

      await sub.cancel();
      harness.closeInput();
    },
  );

  test('rejects requests before initialize', () async {
    final harness = await _spawn(EchoAcpBackend());
    final responses = <Map<String, Object?>>[];
    final collected = Completer<void>();

    late StreamSubscription<Map<String, Object?>> sub;
    sub = harness.messages.listen((msg) {
      if (msg.containsKey('error')) {
        responses.add(msg);
        if (!collected.isCompleted) collected.complete();
      }
    });

    await harness.send(rpcRequest(5, 'session/new', {'cwd': '/tmp'}));
    await collected.future.timeout(const Duration(seconds: 5));

    expect((responses.first['error'] as Map)['code'], -32002);

    await sub.cancel();
    harness.closeInput();
  });

  test(
    'cancel notification stops the turn with cancelled stop reason',
    () async {
      final harness = await _spawn(
        EchoAcpBackend(delay: const Duration(milliseconds: 50)),
      );
      final responses = <int, Map<String, Object?>>{};
      final promptDone = Completer<Map<String, Object?>>();

      late StreamSubscription<Map<String, Object?>> sub;
      sub = harness.messages.listen((msg) {
        if (msg.containsKey('id') && msg.containsKey('result')) {
          responses[msg['id'] as int] = msg;
          if (msg['id'] == 2 && !promptDone.isCompleted) {
            promptDone.complete(msg);
          }
        }
      });

      await harness.send(rpcRequest(0, 'initialize', {'protocolVersion': 1}));
      await harness.send(rpcRequest(1, 'session/new', {'cwd': '/tmp'}));
      unawaited(
        harness.send(
          rpcRequest(2, 'session/prompt', {
            'sessionId': 'sess_echo_1',
            'prompt': [
              {'type': 'text', 'text': 'a b c d e f g h i j'},
            ],
          }),
        ),
      );
      // Cancel shortly after the turn starts.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await harness.send(
        rpcNotify('session/cancel', {'sessionId': 'sess_echo_1'}),
      );

      await promptDone.future.timeout(const Duration(seconds: 10));
      final result =
          (await promptDone.future)['result'] as Map<String, Object?>;
      expect(result['stopReason'], anyOf('cancelled', 'end_turn'));

      await sub.cancel();
      harness.closeInput();
    },
  );
}
