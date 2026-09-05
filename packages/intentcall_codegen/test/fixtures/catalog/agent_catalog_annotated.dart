import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

@AgentCatalog()
final List<AgentRegistryCatalogEntry> supplementCatalogEntries =
    <AgentRegistryCatalogEntry>[
      AgentRegistryCatalogEntry(
        registryKey: 'app_sup_a',
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'sup_a',
          description: 'Supplement catalog row A',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
          },
        ),
      ),
      AgentRegistryCatalogEntry(
        registryKey: 'app_sup_b',
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'sup_b',
          description: 'Supplement catalog row B',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
          },
        ),
      ),
    ];
