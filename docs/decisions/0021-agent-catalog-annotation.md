# 0021. @AgentCatalog Annotation and Removal of Handwritten Catalog Path

Date: 2026-07-07

## Status

Accepted

## Context

`AgentCatalogGenerator` merged catalog rows from three sources:

1. `@AgentTool` codegen (via generated `*.g.dart` parts)
2. A **single hardcoded file** at `lib/catalog/handwritten_entries.dart` exporting
   `handwrittenCatalogEntries` (overridable via `handwritten_catalog_path` /
   `handwritten_catalog_symbol` in `build.yaml`)
3. `@AgentCatalogSupplement` on `List<AgentRegistryCatalogEntry>` discovered via
   `tool_globs`

The handwritten path forced instance-bound and descriptor-only rows into one central
file, breaking co-location with host classes. The supplement annotation solved
multi-file discovery but introduced two overlapping mechanisms and confusing naming.

## Decision

1. **Rename** `AgentCatalogSupplement` → **`AgentCatalog`** (annotation mirrors
   `@AgentTool` naming).
2. **Remove** `handwritten_catalog_path` and `handwritten_catalog_symbol` builder
   options. Manual catalog rows merge only through `@AgentCatalog`.
3. **Document** the three-source mental model:

   ```text
   @AgentTool          →  tool implementation + (usually) catalog row
   handwritten getter  →  tool implementation only
   catalog row         →  @AgentCatalog list
   agent_catalog.g.dart →  merge of all three sources
   ```

4. **Breaking change** (pre-release): apps using the default handwritten file must
   add `@AgentCatalog()` to their list and co-locate it with the owning host.
5. **Discover `@AgentCatalog` on static host fields** (2026-07-07 amendment):
   annotated `List<AgentRegistryCatalogEntry>` may live as a **static** field on a
   host class (recommended) or as a top-level variable. The generator spreads
   static lists as `HostClass.catalogSymbol` (e.g.
   `...DemoHostTools.demoHostCatalogEntries`). **Instance fields are not
   supported** — no compile-time symbol exists for build-time spread.

## Consequences

- Catalog rows live on or next to host classes; no `lib/catalog/handwritten_entries.dart`
  convention.
- `tool_globs` scopes `@AgentCatalog` discovery only; unannotated lists are ignored.
- Static host catalogs are the preferred co-location pattern; top-level lists remain valid.
- Pre-release consumers must migrate from `handwrittenCatalogEntries` to annotated lists.
- Tools already covered by `@AgentTool` codegen must not be duplicated in `@AgentCatalog`
  lists (`registryKey` collision fails the build).

## Related

- [0019-framework-neutral-intentcall-cli.md](0019-framework-neutral-intentcall-cli.md)
- [0020-platform-scoped-manifest-surfaces.md](0020-platform-scoped-manifest-surfaces.md)
- Reference: [`demo_host_tools.dart`](../../packages/intentcall_codegen/example/lib/tools/demo_host_tools.dart)
