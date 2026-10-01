import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';

/// Marks a [AgentRegistryCatalogEntry] list for merge into the generated catalog.
///
/// Annotate a **top-level** or **static** `List<AgentRegistryCatalogEntry>` under
/// `lib/`. [AgentCatalogGenerator] discovers annotated lists via `tool_globs` and
/// spreads them into `lib/generated/agent_catalog.g.dart` alongside `@AgentTool`
/// rows from generated `*.g.dart` parts.
///
/// ## Catalog mental model
///
/// ```text
/// @AgentTool          →  tool implementation + (usually) catalog row
/// handwritten getter  →  tool implementation only
/// catalog row         →  @AgentCatalog list
/// agent_catalog.g.dart →  merge of all three sources
/// ```
///
/// ## Placement
///
/// | Placement | Generated spread | Notes |
/// |-----------|------------------|-------|
/// | Top-level list | `...myCatalogEntries,` | Valid; prefer static host field for co-location |
/// | **Static** field on host class | `...HostClass.myCatalogEntries,` | **Recommended** — catalog lives with getters |
/// | Instance field | — | **Not supported** — no compile-time symbol for spread |
///
/// Unannotated `List<AgentRegistryCatalogEntry>` values are ignored (explicit
/// opt-in). Duplicate `registryKey` values across `@AgentTool` codegen and
/// `@AgentCatalog` lists fail the build.
///
/// ## Example (static host catalog — recommended)
///
/// ```dart
/// final class DemoHostTools {
///   static final DemoHostTools shared = DemoHostTools();
///
///   AgentCallEntry get inboxCallEntry => AgentCallEntry.tool(/* … */);
///
///   @AgentCatalog()
///   static final List<AgentRegistryCatalogEntry> demoHostCatalogEntries =
///       <AgentRegistryCatalogEntry>[
///     AgentRegistryCatalogEntry(
///       registryKey: 'app_demo_inbox',
///       entry: shared.inboxCallEntry,
///       projection: const EntryProjection(
///         surfaces: {AgentManifestSurface.webMcp: true},
///       ),
///     ),
///   ];
/// }
/// ```
///
/// After `dart run build_runner build`, the aggregate catalog contains
/// `...DemoHostTools.demoHostCatalogEntries`.
///
/// See [ADR 0021](https://github.com/Arenukvern/intentcall/blob/main/docs/decisions/0021-agent-catalog-annotation.md).
class AgentCatalog {
  /// Marks a catalog list for discovery by [AgentCatalogGenerator].
  const AgentCatalog();
}
