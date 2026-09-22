import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test(
    'CLI and MCP peers discover the owner and call without a redraw',
    () async {
      var paints = 0;
      final registry = InMemoryAgentRegistry()
        ..register(
          RegisteredAgentIntent(
            descriptor: AgentIntentDescriptor(
              namespace: 'app',
              name: 'echo',
              description: 'Echo for discovery.',
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
              final text = '${invocation.arguments['text']}';
              if (text == 'paint') {
                paints += 1;
              }
              return AgentResult.success(data: <String, Object?>{'text': text});
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
      final directory = AgentLinkDirectory(
        root: Directory.systemTemp.createTempSync('intentcall-links'),
      );
      addTearDown(() async {
        if (directory.root.existsSync()) {
          directory.root.deleteSync(recursive: true);
        }
      });
      final surface = await AgentWebSocketSurface.serve(
        link: hub,
        protocolScheme: 'discoverdemo',
        owner: 'macos',
        directory: directory,
      );
      addTearDown(() async {
        await surface.close();
        await hub.close();
      });

      final found = await directory.find('discoverdemo');
      expect(found, isNotNull);
      expect(found!.owner, 'macos');
      expect(found.discover, startsWith('http://'));

      final page = await invokeAgentWebSocket(
        uri: Uri.parse(found.websocket),
        envelope: IntentCallInvocationEnvelope(
          id: 'web-1',
          qualifiedName: 'app_echo',
          arguments: const <String, Object?>{'text': 'quiet'},
          source: IntentCallInvocationSource.websocket,
        ),
      );
      expect(page.ok, isTrue);
      expect(page.data['text'], 'quiet');
      expect(paints, 0);

      final proxy = await registryFromDiscoveredLink(found);
      final mcp = await proxy.invoke('app_echo', const <String, Object?>{
        'text': 'paint',
      });
      expect(mcp.ok, isTrue);
      expect(mcp.data['text'], 'paint');
      expect(paints, 1);

      await surface.close();
      expect(await directory.find('discoverdemo'), isNull);
    },
  );
}
