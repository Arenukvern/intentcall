import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/src/flutter/intentcall_flutter_host.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_platform_sync/io.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('Flutter host publishes a link other processes can call', () async {
    var paints = 0;
    final directory = Directory.systemTemp.createTempSync('intentcall-host');
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
              paints += 1;
            }
            return AgentResult.success(
              data: <String, Object?>{'text': invocation.arguments['text']},
            );
          },
        ),
      );
    final host = IntentCallFlutterHost.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.websocket},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
      publishSurfaceLink: true,
      protocolScheme: 'hostdemo',
      linkDirectory: directory.path,
      drainOnStart: false,
      drainOnResume: false,
    );
    await host.start();
    final found = await AgentLinkDirectory(root: directory).find('hostdemo');
    expect(found, isNotNull);
    final quiet = await invokeAgentWebSocket(
      uri: Uri.parse(found!.websocket),
      envelope: IntentCallInvocationEnvelope(
        id: 'host-1',
        qualifiedName: 'app_echo',
        arguments: const <String, Object?>{'text': 'quiet'},
        source: IntentCallInvocationSource.websocket,
      ),
    );
    expect(quiet.data['text'], 'quiet');
    expect(paints, 0);
    await host.dispose();
    expect(await AgentLinkDirectory(root: directory).find('hostdemo'), isNull);
    directory.deleteSync(recursive: true);
  });
}
