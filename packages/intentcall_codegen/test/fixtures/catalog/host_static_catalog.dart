import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

final class CatalogHost {
  @AgentCatalog()
  static final List<AgentRegistryCatalogEntry> hostCatalogEntries =
      <AgentRegistryCatalogEntry>[
        AgentRegistryCatalogEntry(
          registryKey: 'app_host_static_a',
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'host_static_a',
            description: 'Static @AgentCatalog row A',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{},
              'required': <String>[],
            },
          ),
        ),
        AgentRegistryCatalogEntry(
          registryKey: 'app_host_static_b',
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'host_static_b',
            description: 'Static @AgentCatalog row B',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{},
              'required': <String>[],
            },
          ),
        ),
      ];
}
