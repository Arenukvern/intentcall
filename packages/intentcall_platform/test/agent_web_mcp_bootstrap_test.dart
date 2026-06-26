import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:test/test.dart';

void main() {
  test('registerAgentWebMcpFromEntries is safe on VM', () {
    expect(
      () => registerAgentWebMcpFromEntries(<AgentCallEntry>{}),
      returnsNormally,
    );
    expect(
      () => registerAgentWebMcpFromEntries(
        <AgentCallEntry>{},
        policy: const IntentCallAuthorizationPolicy.denyAll(),
      ),
      returnsNormally,
    );
  });

  test('registerAgentWebMcpFromRegistry is safe on VM', () {
    expect(
      () => registerAgentWebMcpFromRegistry(InMemoryAgentRegistry()),
      returnsNormally,
    );
    expect(
      () => registerAgentWebMcpFromRegistry(
        InMemoryAgentRegistry(),
        policy: const IntentCallAuthorizationPolicy(
          allowedSources: <String>{IntentCallInvocationSource.webMcpDart},
          allowedQualifiedNames: <String>{'app_echo'},
        ),
      ),
      returnsNormally,
    );
  });
}
