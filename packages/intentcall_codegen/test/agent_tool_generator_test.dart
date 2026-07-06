import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

import '../example/lib/tools/demo_ping_tool.dart';

void main() {
  test('generated demoPingRegistration validates before execute', () {
    expect(
      () => demoPingRegistration.validate(const <String, Object?>{}),
      throwsA(isA<AgentValidationException>()),
    );
  });

  test('generated demoPingRegistration invokes handler', () async {
    final registration = demoPingRegistration;
    expect(registration.qualifiedName, 'app_demo_ping');
    expect(registration.descriptor.inputSchema['required'], ['message']);

    final result = await registration.execute(
      AgentInvocation(
        descriptor: registration.descriptor,
        arguments: const {'message': 'hi'},
      ),
    );
    expect(result.ok, isTrue);
    expect(result.data['pong'], 'hi');
  });

  test('generated demoPingCallEntry registers via toRegistration', () {
    expect(demoPingCallEntry.name, 'demo_ping');
    expect(demoPingCallEntry.toRegistration().qualifiedName, 'app_demo_ping');
  });

  test(
    'generated demoCartCallEntry omits absent optional named args',
    () async {
      final result = await demoCartRegistration.execute(
        AgentInvocation(
          descriptor: demoCartRegistration.descriptor,
          arguments: const <String, Object?>{'currency': 'USD'},
        ),
      );

      expect(result.ok, isTrue);
      expect(result.data['currency'], 'USD');
      expect(result.data['includeTax'], isFalse);
    },
  );

  test(
    'generated demoCartCallEntry passes present optional named args',
    () async {
      final result = await demoCartRegistration.execute(
        AgentInvocation(
          descriptor: demoCartRegistration.descriptor,
          arguments: const <String, Object?>{
            'currency': 'USD',
            'includeTax': true,
          },
        ),
      );

      expect(result.ok, isTrue);
      expect(result.data['includeTax'], isTrue);
    },
  );

  test('generated required named params are emitted unconditionally', () async {
    expect(demoRequiredNamedRegistration.descriptor.inputSchema['required'], [
      'mode',
    ]);

    final result = await demoRequiredNamedRegistration.execute(
      AgentInvocation(
        descriptor: demoRequiredNamedRegistration.descriptor,
        arguments: const <String, Object?>{'mode': 'slow'},
      ),
    );

    expect(result.ok, isTrue);
    expect(result.data['mode'], 'slow');
  });
}
