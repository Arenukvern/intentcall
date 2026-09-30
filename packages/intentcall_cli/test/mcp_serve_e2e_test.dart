import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intentcall_cli/src/mcp/mcp_serve_plan.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('parseFlutterMachineVmUri reads a machine event', () {
    final uri = parseFlutterMachineVmUri(
      '{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:8181/ws"}}',
    );
    expect(uri, Uri.parse('ws://127.0.0.1:8181/ws'));
  });

  test('auto prefers an explicit debug VM over a live link', () async {
    final directory = AgentLinkDirectory(
      root: Directory.systemTemp.createTempSync('intentcall-plan'),
    );
    addTearDown(() => directory.root.delete(recursive: true));
    final plan = await planMcpServe(
      auto: true,
      scheme: 'e2edemo',
      directory: directory,
      vmServiceUri: Uri.parse('ws://127.0.0.1:9/ws'),
      discoverVm: () async => null,
    );
    expect(plan.kind, McpServeKind.vm);
    expect(plan.vmServiceUri, Uri.parse('ws://127.0.0.1:9/ws'));
  });

  test('auto serves a status tool when nothing is running', () async {
    final directory = AgentLinkDirectory(
      root: Directory.systemTemp.createTempSync('intentcall-empty'),
    );
    addTearDown(() => directory.root.delete(recursive: true));
    final tools = await _mcpTools(
      arguments: <String>[
        'mcp',
        'serve',
        '--auto',
        '--scheme',
        'missing',
        '--directory',
        directory.root.path,
      ],
    );
    expect(tools, contains('intentcall_app_status'));
  });

  test('cli and mcp reach a published owner without a redraw', () async {
    final owner = await _Owner.start();
    addTearDown(owner.close);
    final discovered = await Process.run(Platform.resolvedExecutable, [
      'bin/intentcall.dart',
      'link',
      'discover',
      '--scheme',
      'e2edemo',
      '--directory',
      owner.directory.root.path,
    ], workingDirectory: _cliRoot);
    expect(discovered.exitCode, 0, reason: '${discovered.stderr}');
    final announcement =
        jsonDecode(discovered.stdout as String) as Map<String, Object?>;
    expect(announcement['owner'], 'macos');

    final quiet = await Process.run(Platform.resolvedExecutable, [
      'bin/intentcall.dart',
      'link',
      'call',
      '--scheme',
      'e2edemo',
      '--directory',
      owner.directory.root.path,
      '--name',
      'app_echo',
      '--args',
      '{"text":"quiet"}',
    ], workingDirectory: _cliRoot);
    expect(quiet.exitCode, 0, reason: '${quiet.stderr}');
    expect(jsonDecode(quiet.stdout as String), containsPair('text', 'quiet'));
    expect(owner.paints, 0);

    final tools = await _mcpTools(
      arguments: <String>[
        'mcp',
        'serve',
        '--auto',
        '--scheme',
        'e2edemo',
        '--directory',
        owner.directory.root.path,
      ],
      call: <String, Object?>{
        'name': 'app_echo',
        'arguments': <String, Object?>{'text': 'paint'},
      },
    );
    expect(tools, contains('app_echo'));
    expect(owner.paints, 1);
  });
}

String get _cliRoot => Directory.current.path.endsWith('intentcall_cli')
    ? Directory.current.path
    : '${Directory.current.path}/packages/intentcall_cli';

final class _Owner {
  _Owner(this.directory, this.surface, this.hub);

  final AgentLinkDirectory directory;
  final AgentWebSocketSurface surface;
  final AgentInvocationHub hub;
  int paints = 0;

  static Future<_Owner> start() async {
    final directory = AgentLinkDirectory(
      root: Directory.systemTemp.createTempSync('intentcall-e2e'),
    );
    late final _Owner owner;
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'Echo.',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'text': <String, Object?>{'type': 'string'},
              },
              'required': <String>['text'],
            },
          ),
          execute: (final invocation) async {
            if (invocation.arguments['text'] == 'paint') {
              owner.paints += 1;
            }
            return AgentResult.success(
              data: <String, Object?>{'text': invocation.arguments['text']},
            );
          },
        ),
      );
    final hub = AgentInvocationHub.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.websocket},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
    );
    final surface = await AgentWebSocketSurface.serve(
      link: hub,
      protocolScheme: 'e2edemo',
      owner: 'macos',
      directory: directory,
    );
    owner = _Owner(directory, surface, hub);
    return owner;
  }

  Future<void> close() async {
    await surface.close();
    await hub.close();
    if (directory.root.existsSync()) {
      directory.root.deleteSync(recursive: true);
    }
  }
}

Future<List<String>> _mcpTools({
  required final List<String> arguments,
  final Map<String, Object?>? call,
}) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'bin/intentcall.dart',
    ...arguments,
  ], workingDirectory: _cliRoot);
  final stdoutLines = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final pending = <int, Map<String, Object?>>{};
  final done = Completer<List<String>>();
  stdoutLines.listen((final line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (decoded is! Map) {
      return;
    }
    final message = Map<String, Object?>.from(decoded);
    final id = message['id'];
    if (id is int) {
      pending[id] = message;
    }
    if (pending.containsKey(1) && !pending.containsKey(2)) {
      process.stdin.writeln(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      process.stdin.writeln(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
        }),
      );
    }
    if (pending.containsKey(2) && call != null && !pending.containsKey(3)) {
      process.stdin.writeln(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/call',
          'params': call,
        }),
      );
    }
    final finished = call == null
        ? pending.containsKey(2)
        : pending.containsKey(3);
    if (finished && !done.isCompleted) {
      final listed = pending[2]!['result'];
      final names = <String>[];
      if (listed is Map && listed['tools'] is List) {
        for (final tool in listed['tools'] as List) {
          if (tool is Map && tool['name'] is String) {
            names.add(tool['name'] as String);
          }
        }
      }
      done.complete(names);
    }
  });
  process.stdin.writeln(
    jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': <String, Object?>{
        'protocolVersion': '2024-11-05',
        'capabilities': <String, Object?>{},
        'clientInfo': <String, Object?>{'name': 'e2e', 'version': '0'},
      },
    }),
  );
  final names = await done.future.timeout(const Duration(seconds: 20));
  process.kill();
  return names;
}
