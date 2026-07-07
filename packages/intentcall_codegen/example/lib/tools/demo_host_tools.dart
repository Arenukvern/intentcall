import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'demo_host_tools.g.dart';

final class DemoHostTools {
  DemoHostTools();

  static final DemoHostTools shared = DemoHostTools();

  static const inboxProjection = EntryProjection(
    surfaces: {AgentManifestSurface.webMcp: true},
  );

  Future<AgentResult> inbox(final String folder) async {
    return AgentResult.success(
      data: {
        'folder': folder,
        'messages': <String>['Welcome to $folder', 'You have 2 unread items'],
      },
    );
  }

  @AgentTool(
    namespace: 'app',
    name: 'demo_host_status',
    description: 'Codegen instance-method host tool',
  )
  @AgentProjection(surfaces: {AgentManifestSurface.webMcp: true})
  Future<AgentResult> hostStatus(@AgentParam('Host label') String label) async {
    return AgentResult.success(
      data: {
        'label': label,
        'source': 'codegen_instance',
        'host': 'DemoHostTools',
      },
    );
  }

  Future<AgentResult> demoHandwritten(final String note) async {
    return AgentResult.success(
      data: {'note': note, 'source': 'handwritten', 'host': 'DemoHostTools'},
    );
  }

  AgentCallEntry get inboxCallEntry => AgentCallEntry.tool(
    namespace: 'app',
    name: 'demo_inbox',
    description: 'Read inbox folder',
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'folder': <String, Object?>{
          'type': 'string',
          'description': 'Inbox folder name',
        },
      },
      'required': <String>['folder'],
    },
    handler: (final args) async => inbox(args['folder'] as String),
  );

  AgentCallEntry get demoHandwrittenCallEntry => AgentCallEntry.tool(
    namespace: 'app',
    name: 'demo_handwritten',
    description: 'Handwritten instance-bound tool',
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'note': <String, Object?>{
          'type': 'string',
          'description': 'Note to echo',
        },
      },
      'required': <String>['note'],
    },
    handler: (final args) async => demoHandwritten(args['note'] as String),
  );
}

@AgentCatalog()
final List<AgentRegistryCatalogEntry> demoHostCatalogEntries =
    <AgentRegistryCatalogEntry>[
      AgentRegistryCatalogEntry(
        registryKey: 'app_demo_inbox',
        entry: DemoHostTools.shared.inboxCallEntry,
        projection: DemoHostTools.inboxProjection,
      ),
      AgentRegistryCatalogEntry(
        registryKey: 'app_demo_handwritten',
        entry: DemoHostTools.shared.demoHandwrittenCallEntry,
      ),
    ];
