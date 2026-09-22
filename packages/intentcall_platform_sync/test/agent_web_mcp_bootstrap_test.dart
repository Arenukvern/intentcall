import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('registerAgentWebMcpFromEntries reports unavailable on VM', () {
    final report = registerAgentWebMcpFromEntries(<AgentCallEntry>{});
    expect(report.available, isFalse);
    expect(report.registered, isEmpty);
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
