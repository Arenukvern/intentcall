import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

final List<AgentRegistryCatalogEntry> unannotatedCatalogEntries =
    <AgentRegistryCatalogEntry>[
      AgentRegistryCatalogEntry(
        registryKey: 'app_wrong_a',
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'wrong_a',
          description: 'Unannotated catalog row A',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
          },
        ),
      ),
      AgentRegistryCatalogEntry(
        registryKey: 'app_wrong_b',
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'wrong_b',
          description: 'Unannotated catalog row B',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
          },
        ),
      ),
    ];
