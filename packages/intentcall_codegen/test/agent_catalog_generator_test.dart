import 'package:test/test.dart';

import '../example/lib/generated/agent_catalog.g.dart';

void main() {
  test('aggregates top-level @AgentTool into catalog', () {
    final rows = agentCatalogEntries
        .map((final row) => row.registryKey)
        .toSet();
    expect(rows, contains('app_demo_ping'));
    expect(
      agentCatalogEntries.any(
        (final row) => row.registryKey == 'app_demo_ping' && row.entry != null,
      ),
      isTrue,
    );
  });

  test('instance @AgentTool catalog row uses Host.shared.getter', () {
    final hostStatus = agentCatalogEntries.singleWhere(
      (final row) => row.registryKey == 'app_demo_host_status',
    );
    expect(hostStatus.entry, isNotNull);
    expect(hostStatus.qualifiedName, 'app_demo_host_status');
  });

  test('merges @AgentCatalog rows from example', () {
    final keys = agentCatalogEntries
        .map((final row) => row.registryKey)
        .toSet();
    expect(keys, contains('app_demo_inbox'));
    expect(keys, contains('app_demo_handwritten'));
  });

  test('merges @AgentEntity descriptor rows from example', () {
    expect(agentEntityTypeDescriptors, hasLength(1));
    expect(agentEntityTypeDescriptors.single.qualifiedName, 'app_project');
  });

  test('example agent_catalog has no duplicate registry keys', () {
    final keys = agentCatalogEntries
        .map((final row) => row.registryKey)
        .toList();
    expect(keys.toSet().length, keys.length);
  });
}
