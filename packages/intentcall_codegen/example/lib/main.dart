import 'package:intentcall_core/intentcall_core.dart';

import 'generated/agent_catalog.g.dart';
import 'tools/demo_host_tools.dart';

Future<void> main() async {
  final registry = InMemoryAgentRegistry();
  final liveHost = DemoHostTools();

  for (final row in agentCatalogEntries) {
    if (row.registryKey == 'app_demo_host_status') {
      continue;
    }
    final entry = row.entry;
    if (entry != null) {
      registry.register(entry.toRegistration());
    }
  }
  registry.register(liveHost.demoHostStatusCallEntry.toRegistration());

  final inbox = await registry.invoke('app_demo_inbox', {'folder': 'inbox'});
  if (!inbox.ok) {
    throw StateError('demo_inbox smoke failed: ${inbox.message}');
  }

  final handwritten = await registry.invoke('app_demo_handwritten', {
    'note': 'hello',
  });
  if (!handwritten.ok) {
    throw StateError('demo_handwritten smoke failed: ${handwritten.message}');
  }

  final hostStatus = await registry.invoke('app_demo_host_status', {
    'label': 'primary',
  });
  if (!hostStatus.ok) {
    throw StateError('demo_host_status smoke failed: ${hostStatus.message}');
  }
  if (hostStatus.data['source'] != 'codegen_instance') {
    throw StateError(
      'demo_host_status smoke failed: expected codegen_instance source',
    );
  }
}
