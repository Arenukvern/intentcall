import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:test/test.dart';

void main() {
  test('registerAgentWebMcpFromEntries is safe on VM', () {
    expect(
      () => registerAgentWebMcpFromEntries(<AgentCallEntry>{}),
      returnsNormally,
    );
  });
}
