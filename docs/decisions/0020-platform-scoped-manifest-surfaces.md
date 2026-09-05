# 0020. Platform-Scoped Manifest Surface Defaults

Date: 2026-07-07

## Status

Accepted

## Context

`intentcall.yaml` `platforms.enabled` gates which targets `intentcall platform sync`
runs, but manifest export ignored it. `ProjectionPolicy.resolvedDefaultSurfaces()`
applied cross-platform `defaultSurfaceInclude()` to every tool, so web-only hosts
committed android/windows/linux surface rows in `agent_manifest.json`.

Per-entry `@AgentProjection` / `EntryProjection` overlays merge onto defaults — a
partial overlay such as `{webMcp: true}` does not disable other platform families.

Instance host wiring also treated `static shared` as mandatory for codegen, even
though runtime registration uses live host instances and manifest export only
needs descriptor metadata (`descriptor:` rows or optional probe anchors).

## Decision

1. **`platforms.enabled` scopes default manifest surface families** during export.
   When the list is non-empty, surfaces map to platform tokens (web, android, ios,
   macos, windows, linux) and default to `include: false` outside enabled platforms.
2. **Precedence:** explicit `defaults.surfaces` in yaml wins; then platform-scoped
   defaults; then legacy cross-platform defaults when `platforms.enabled` is empty.
3. **`static shared` is optional** for instance `@AgentTool` codegen. Extension
   getters remain; catalog emits `descriptor:` rows when no binding static exists;
   `entry: Host.shared.*` remains when the probe anchor is present.
4. **`@AgentProjection.surfaces` uses typed `AgentManifestSurface` keys.** Apple
   sub-channels (Siri, Spotlight, extensions) use `AgentManifestSurfaceExposure.options`
   on handwritten rows until emitters define them.

## Consequences

- Web-only example manifests list web surfaces as `include: true` by default.
- Flutter multi-platform hosts with empty `platforms.enabled` keep unified defaults.
- Authors register instance tools from live host objects; catalog `entry:` is optional.

## Related

- [0016-dispatch-mode-handoff-contract.md](0016-dispatch-mode-handoff-contract.md)
- [0019-framework-neutral-intentcall-cli.md](0019-framework-neutral-intentcall-cli.md)
