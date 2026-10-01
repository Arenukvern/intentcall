import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  test('projectEntriesToWebMcp reports unavailable on VM', () {
    final report = projectEntriesToWebMcp(<AgentCallEntry>{});
    expect(report.available, isFalse);
    expect(report.registered, isEmpty);
    expect(
      () => projectEntriesToWebMcp(
        <AgentCallEntry>{},
        policy: const IntentCallAuthorizationPolicy.denyAll(),
      ),
      returnsNormally,
    );
  });

  test('projectRegistryToWebMcp is safe on VM', () {
    expect(
      () => projectRegistryToWebMcp(InMemoryAgentRegistry()),
      returnsNormally,
    );
    expect(
      () => projectRegistryToWebMcp(
        InMemoryAgentRegistry(),
        policy: const IntentCallAuthorizationPolicy(
          allowedSources: <String>{IntentCallInvocationSource.webMcpDart},
          allowedQualifiedNames: <String>{'app_echo'},
        ),
      ),
      returnsNormally,
    );
  });

  test('WebMcpProjection forwards entries with the explicit policy', () {
    const projection = WebMcpProjection(
      policy: IntentCallAuthorizationPolicy.denyAll(),
    );
    expect(
      () => projection.entriesChanged(<AgentCallEntry>{}),
      returnsNormally,
    );
  });
}
