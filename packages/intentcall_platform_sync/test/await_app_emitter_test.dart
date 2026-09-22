import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('awaitApp Swift waits on the host and does not queue', () {
    final manifest = AgentManifest.fromJson(<String, Object?>{
      'version': 1,
      'protocolScheme': 'demo',
      'tools': <Object?>[
        <String, Object?>{
          'qualifiedName': 'app_echo',
          'namespace': 'app',
          'name': 'echo',
          'description': 'Echo',
          'kind': 'tool',
          'dispatchMode': 'awaitApp',
          'surfaces': <String, Object?>{
            'apple.appIntents': <String, Object?>{'include': true},
          },
          'inputSchema': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'text': <String, Object?>{'type': 'string'},
            },
            'required': <String>['text'],
          },
        },
      ],
    });

    final swift = const AppleSwiftAppIntentsEmitter().emit(manifest);

    expect(swift, contains('IntentCallNativeBridge.invokeAwaiting'));
    expect(swift, contains('fallbackProtocolScheme: "demo"'));
    expect(swift, contains('outcome.dialog'));
    expect(swift, isNot(contains('Queued invocation')));
    expect(swift, isNot(contains('IntentCallNativeBridge.enqueue')));
    expect(swift, contains('static var openAppWhenRun: Bool = true'));
  });
}
