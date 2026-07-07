import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// Marks a top-level [AgentRegistryCatalogEntry] list for catalog merge.
///
/// Annotate a `List<AgentRegistryCatalogEntry>` anywhere under `lib/`.
/// [AgentCatalogGenerator] discovers annotated lists and spreads them into
/// `lib/generated/agent_catalog.g.dart` alongside `@AgentTool` rows.
class AgentCatalog {
  const AgentCatalog();
}
