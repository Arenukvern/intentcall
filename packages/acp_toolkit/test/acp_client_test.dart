import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

/// Pipe adapter: forwards written lines into a byte stream controller.
final class _ControllerSink implements StringSink {
  _ControllerSink(this._controller);

  final StreamController<List<int>> _controller;

  @override
  void writeln([Object? object = '']) =>
      _controller.add(utf8.encode('$object\n'));

  @override
  void write(Object? object) => _controller.add(utf8.encode('$object'));

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
}

/// Captures each written line as a decoded JSON map, optionally forwarding.
final class _RecordingSink implements StringSink {
  _RecordingSink({StringSink? forward}) : _forward = forward;

  final StringSink? _forward;
  final List<Map<String, Object?>> lines = [];

  @override
  void writeln([Object? object = '']) {
    final text = '$object';
    if (text.trim().isEmpty) return;
    lines.add((jsonDecode(text) as Map).cast<String, Object?>());
    _forward?.writeln(text);
  }

  @override
  void write(Object? object) => writeln(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
}

void main() {
  test('client round-trips a prompt turn against an in-process echo server',
      () async {
    final fromClient = StreamController<List<int>>();
    final fromServerBytes = StreamController<List<int>>();

    final server = AcpStdioServer(
      backend: EchoAcpBackend(),
      inputStream: fromClient.stream,
      outputSink: _ControllerSink(fromServerBytes),
    );
    server.run().ignore();

    final clientInput = _RecordingSink(forward: _ControllerSink(fromClient));
    final client = AcpClient(
      agentOutput: fromServerBytes.stream,
      agentInput: clientInput,
    );

    await client.initialize();

    final sessionId = await client.newSession(cwd: '/tmp/acp-client-test');
    expect(sessionId, isNotEmpty);
    expect(
      clientInput.lines.first['method'],
      'initialize',
      reason: 'initialize must be the first request on the wire',
    );

    final updates = <AcpSessionUpdate>[];
    final result = await client.promptText(
      sessionId,
      'hello world',
      onUpdate: updates.add,
    );

    expect(result.stopReason, AcpStopReason.endTurn);
    expect(updates.whereType<Plan>(), isNotEmpty);
    expect(updates.whereType<ToolCallUpdate>(), isNotEmpty);

    final echoed = updates
        .whereType<AgentMessageChunk>()
        .map((u) => (u.content as AcpTextBlock).text)
        .join();
    expect(echoed.trim(), 'hello world');

    await client.dispose();
    await fromClient.close();
    await fromServerBytes.close();
  });

  test('client answers session/request_permission via permissionHandler',
      () async {
    final fromServer = StreamController<List<int>>();
    final input = _RecordingSink();
    var asked = false;

    final client = AcpClient(
      agentOutput: fromServer.stream,
      agentInput: input,
      permissionHandler: (request) async {
        asked = true;
        expect(request.toolCallId, 'call_1');
        expect(request.title, 'Write file');
        return AcpPermissionOutcome.allow;
      },
    );

    // Simulate an agent asking for permission.
    fromServer.add(utf8.encode(jsonEncode({
      'jsonrpc': '2.0',
      'id': 7,
      'method': 'session/request_permission',
      'params': {
        'sessionId': 's1',
        'toolCallId': 'call_1',
        'options': [
          {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
          {'optionId': 'reject', 'name': 'Reject', 'kind': 'reject_once'},
        ],
        '_meta': {'title': 'Write file', 'kind': 'edit'},
      },
    })));
    fromServer.add(utf8.encode('\n'));
    await fromServer.close();

    expect(asked, isTrue);
    final response = input.lines.single;
    expect(response['id'], 7);
    final outcome =
        (response['result'] as Map<String, Object?>)['outcome']
            as Map<String, Object?>;
    expect(outcome['optionId'], 'allow');
    expect(client.isClosed, isTrue); // stream closed → client closed

    await fromServer.close();
  });

  test('client without permissionHandler rejects safely', () async {
    final fromServer = StreamController<List<int>>();
    final input = _RecordingSink();

    final client = AcpClient(
      agentOutput: fromServer.stream,
      agentInput: input,
    );

    fromServer.add(utf8.encode(jsonEncode({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'session/request_permission',
      'params': {
        'sessionId': 's1',
        'toolCallId': 'call_1',
        'options': [
          {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
          {'optionId': 'reject', 'name': 'Reject', 'kind': 'reject_once'},
        ],
      },
    })));
    fromServer.add(utf8.encode('\n'));
    await fromServer.close();

    final result = input.lines.single['result'] as Map<String, Object?>;
    final outcome = result['outcome'] as Map<String, Object?>;
    expect(outcome['outcome'], 'rejected');
    expect(outcome['optionId'], 'reject');
    expect(client.isClosed, isTrue);
  });

  test('unknown session/update kinds are preserved, not fatal', () {
    final update = AcpSessionUpdate.fromJson({
      'sessionUpdate': 'brand_new_kind_from_v2_agent',
      'content': {'type': 'text', 'text': 'x'},
    });
    expect(update, isA<UnknownSessionUpdate>());
    expect(
      (update as UnknownSessionUpdate).kind,
      'brand_new_kind_from_v2_agent',
    );
  });

  test('prompt before initialize throws', () async {
    final fromServer = StreamController<List<int>>();
    final client = AcpClient(
      agentOutput: fromServer.stream,
      agentInput: _RecordingSink(),
    );
    await fromServer.close();
    expect(() => client.promptText('s', 'hi'), throwsStateError);
  });
}
