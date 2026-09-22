import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('omits App Actions artifacts when no entry opts in', () {
    final manifest = AgentManifest.fromJson(<String, Object?>{
      'version': 1,
      'protocolScheme': 'demo',
      'tools': <Object?>[_tool(include: false)],
    });

    expect(const WindowsAppActionsEmitter().emitRegistration(manifest), isNull);
    expect(
      const WindowsAppActionsEmitter().emitManifestFragment(manifest),
      isNull,
    );
  });

  test('emits URI registration for primitive parameters', () {
    final manifest = AgentManifest.fromJson(<String, Object?>{
      'version': 1,
      'protocolScheme': 'demo',
      'tools': <Object?>[_tool(include: true)],
    });

    final raw = const WindowsAppActionsEmitter().emitRegistration(manifest);
    final json = jsonDecode(raw!) as Map<String, Object?>;
    final action = (json['actions']! as List).single as Map<String, Object?>;
    expect(action['id'], 'app_echo');
    expect(action['invocation'], <String, Object?>{
      'type': 'Uri',
      'uri': 'demo://actions/app_echo',
      'inputData': <String, Object?>{'text': r'${text.Text}'},
    });
    expect((action['outputs']! as List).single, <String, Object?>{
      'name': 'result',
      'kind': 'Text',
    });
    final fragment = const WindowsAppActionsEmitter().emitManifestFragment(
      manifest,
    );
    expect(fragment, contains('ReturnResults="always"'));
    expect(fragment, contains('com.microsoft.windows.ai.actions'));
    expect(fragment, contains('intentcall_app_actions.json'));
  });

  test('rejects nested App Actions parameters', () {
    final manifest = AgentManifest.fromJson(<String, Object?>{
      'version': 1,
      'protocolScheme': 'demo',
      'tools': <Object?>[
        _tool(
          include: true,
          properties: <String, Object?>{
            'payload': <String, Object?>{'type': 'object'},
          },
        ),
      ],
    });

    expect(
      () => const WindowsAppActionsEmitter().emitRegistration(manifest),
      throwsUnsupportedError,
    );
  });

  test('executor returns AgentResult JSON for an allowed call', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'echo',
            description: 'echo',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (final invocation) async => AgentResult.success(
            data: <String, Object?>{'text': invocation.arguments['text']},
          ),
        ),
      );
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: registry,
      policy: const IntentCallAuthorizationPolicy(
        allowedSources: <String>{IntentCallInvocationSource.windowsAppAction},
        allowedQualifiedNames: <String>{'app_echo'},
      ),
    );

    final output = await executeWindowsAppAction(
      bridge: bridge,
      qualifiedName: 'app_echo',
      inputs: const <String, Object?>{'text': 'hi'},
      invocationId: 'fixed',
    );

    expect(jsonDecode(output['result']! as String), <String, Object?>{
      'ok': true,
      'text': 'hi',
    });
  });

  test('executor reports denial inside the result text', () async {
    final bridge = IntentCallNativeBridge.bindRegistry(
      registry: InMemoryAgentRegistry(),
    );

    final output = await executeWindowsAppAction(
      bridge: bridge,
      qualifiedName: 'app_echo',
      inputs: const <String, Object?>{},
      invocationId: 'fixed',
    );
    final payload = jsonDecode(output['result']! as String) as Map;
    expect(payload['ok'], isFalse);
    expect(payload['code'], 'invocation_denied');
  });
}

Map<String, Object?> _tool({
  required final bool include,
  final Map<String, Object?> properties = const <String, Object?>{
    'text': <String, Object?>{'type': 'string'},
  },
}) => <String, Object?>{
  'qualifiedName': 'app_echo',
  'namespace': 'app',
  'name': 'echo',
  'description': 'Echo text',
  'kind': 'tool',
  'surfaces': <String, Object?>{
    'windows.appActions': <String, Object?>{'include': include},
  },
  'inputSchema': <String, Object?>{
    'type': 'object',
    'properties': properties,
    'required': <String>['text'],
  },
};
