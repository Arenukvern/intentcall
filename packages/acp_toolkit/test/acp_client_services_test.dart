import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('terminal capability requires the complete lifecycle', () {
    expect(
      () => AcpClientServices(
        canAccessSession: (_) => true,
        terminalMethods: {'terminal/create': (_) async => {}},
      ),
      throwsArgumentError,
    );
  });

  test('service authority is rechecked for every request', () async {
    var permitted = true;
    var reads = 0;
    final services = AcpClientServices(
      canAccessSession: (id) => permitted && id == 'owned',
      readTextFile: (_) async => {'content': '${++reads}'},
    );
    expect(services.capabilities['fs'], {
      'readTextFile': true,
      'writeTextFile': false,
    });
    expect(await services.handle('fs/read_text_file', {'sessionId': 'owned'}), {
      'content': '1',
    });
    permitted = false;
    for (final id in ['owned', 'foreign', '']) {
      await expectLater(
        services.handle('fs/read_text_file', {'sessionId': id}),
        throwsStateError,
      );
    }
    expect(reads, 1);
  });

  test(
    'unbound services cannot escape through generic extension handler',
    () async {
      final output = StreamController<List<int>>();
      final sink = StringBuffer();
      var extensions = 0;
      final client = AcpClient(
        agentOutput: output.stream,
        agentInput: sink,
        serverRequestHandler: (_, _) async {
          extensions++;
          return {};
        },
      );
      output.add(
        utf8.encode(
          '${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'fs/read_text_file',
            'params': {'sessionId': 'foreign'},
          })}\n',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final response = jsonDecode(sink.toString()) as Map;
      expect((response['error'] as Map)['code'], -32601);
      expect(extensions, 0);
      await client.dispose();
      await output.close();
    },
  );

  test(
    'initialize and both session methods preserve declared contract',
    () async {
      final output = StreamController<List<int>>();
      final sink = StringBuffer();
      final client = AcpClient(
        agentOutput: output.stream,
        agentInput: sink,
        services: AcpClientServices(
          canAccessSession: (id) => id == 'owned',
          readTextFile: (_) async => {'content': 'ok'},
        ),
      );
      Future<Map<String, dynamic>> complete(
        Future<Object?> pending,
        Map<String, Object?> result,
      ) async {
        final request =
            jsonDecode(sink.toString().trim().split('\n').last)
                as Map<String, dynamic>;
        output.add(
          utf8.encode(
            '${jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result})}\n',
          ),
        );
        await pending;
        return request;
      }

      final initialize = await complete(client.initialize(), {
        'protocolVersion': 1,
      });
      expect((initialize['params'] as Map)['clientCapabilities'], {
        'fs': {'readTextFile': true, 'writeTextFile': false},
        'terminal': false,
      });
      const servers = [
        {
          'name': 'local',
          'command': 'owned-adapter',
          'args': <String>[],
          'env': <Object>[],
        },
      ];
      final fresh = await complete(
        client.newSession(cwd: '/owned', mcpServers: servers),
        {'sessionId': 'owned'},
      );
      final loaded = await complete(
        client.loadSession('owned', cwd: '/owned', mcpServers: servers),
        {'sessionId': 'owned'},
      );
      expect((fresh['params'] as Map)['mcpServers'], servers);
      expect((loaded['params'] as Map)['mcpServers'], servers);
      await client.dispose();
      await output.close();
    },
  );
}
