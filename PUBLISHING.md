# Publishing intentcall to pub.dev

Status: publishable `intentcall_*` packages release through
[dart_changesets](https://github.com/Arenukvern/dart_changesets) — intent
files declare bumps, the dependency graph cascades dependents, and one tag
per package drives the per-tag publish (migrated from the release-please
synchronized train, 2026-11-21). First-publish and manual execute commands
remain as historical or recovery guidance.

## Automatic release and publish flow

1. Conventional commits land on `main` (commit discipline unchanged).
2. Write an intent file in the PR: `.changesets/<name>.md`
   (frontmatter: `'intentcall_core': minor` + changelog prose). One file per
   intended release; dependents cascade automatically when caret constraints
   no longer admit the new versions.
3. On merge to `main`, `.github/workflows/dart_changesets.yml` assembles ONE
   `chore: version packages` PR (pubspec bumps + changelogs + dependent
   constraint rewrites) from pending intent files.
4. Merging that PR pushes one tag per release
   (`intentcall_core-v<version>`) and dispatches
   `.github/workflows/dart_changesets_publish.yml` once per tag.
5. Each publish run publishes exactly its own package: static check →
   skip-existing → dependency wait → strict dry-run → OIDC publish →
   wait-visible. Reruns are safe (skip-existing); ordering emerges from the
   dependency waits.

Replaces the release-please flow (`release-please.yml`,
`release-please-config.json`, `release-pr-sync-train.yml`,
`publish_train.yml` — removed). No conventional-commit-to-version mapping is
required anymore: release intent lives in reviewed `.changesets/` files.

## Required GitHub and pub.dev configuration

- The caller workflow runs the `pub.dev` environment (required reviewers
  there gate publishing). No repository secret is required — tag pushes and
  dispatches ride `GITHUB_TOKEN`, and publishing uses GitHub OIDC through
  `dart-lang/setup-dart`.
- On pub.dev, automated publishing stays enabled per package for repository
  `Arenukvern/intentcall` with the package-specific tag pattern:

```text
intentcall_schema-v{{version}}
intentcall_core-v{{version}}
intentcall_session-v{{version}}
intentcall_mcp-v{{version}}
intentcall_webmcp-v{{version}}
intentcall_codegen-v{{version}}
intentcall_platform_sync-v{{version}}
intentcall_hooks-v{{version}}
intentcall_bridge-v{{version}}
intentcall_cli-v{{version}}
intentcall_platform-v{{version}}
intentcall_testing-v{{version}}
```

No long-lived pub.dev token is required in GitHub Actions. The publish workflow
uses GitHub OIDC through `dart-lang/setup-dart`.

## Prerequisites

- `dart pub` logged in (`dart pub token add https://pub.dev`) for LOCAL publishes
- `just test` green in this workspace
- Release-critical worktrees clean; pub treats modified checked-in package files as publish blockers

## Order (reference)

Per-tag fan-out orders itself through dependency waits; this is the
dependency order for reading/recovery:

1. `intentcall_schema`
2. `intentcall_core`
3. `intentcall_session`
4. `intentcall_mcp`, `intentcall_webmcp`, `intentcall_codegen`
5. `intentcall_platform_sync`, `intentcall_hooks`, `intentcall_bridge`, `intentcall_cli`
6. `intentcall_platform` (Flutter plugin)
7. `intentcall_platform_apple`, `intentcall_platform_android` (federated impls)
8. `intentcall_testing`

Versions now move per package (graph cascade) instead of one synchronized
train version.

## Commands

```bash
# Historical first-publish check: only for brand-new package names
just publish-preflight-first

# Later releases: check version consistency, release git cleanliness, and pub.dev credentials
just publish-preflight

# Validate all packages (CI uses this)
just publish-dry-run

# Validate one package tag the way automated publishing does
just publish-tag-dry-run intentcall_session-v<version>

# Diagnostic only while release-critical files are dirty; still fails archive/content errors
just publish-dry-run-ignore-warnings

# Recovery-only: after credentials are configured and automated publishing is unavailable
just publish-execute

# CI normally runs this from .github/workflows/dart_changesets_publish.yml
# (per-tag fan-out after the version PR merge); dispatch is the manual rescue:
# gh workflow run dart_changesets_publish.yml -f tag=intentcall_session-v<version> -f execute=true
just publish-tag-execute intentcall_session-v<version>
```

For a brand-new package name, treat `just publish-preflight-first` as the release desk:

- All `intentcall_*` package names must report available on pub.dev.
- The release-critical tree must be clean: publishable `packages/intentcall_*` files plus `tool/intentcall`, including newly added public API files such as `packages/intentcall_core/lib/intentcall_core_migration.dart`.
- `dart pub token list` must show a configured token for pub.dev.
- `just publish-dry-run` must pass from the same clean release commit before any recovery manual publish.

`just publish-dry-run-ignore-warnings` is only for diagnosing archive/content issues before the release-critical tree is clean. It must not replace the strict dry-run above.

For `intentcall_platform`, if `dart pub publish` fails on Flutter constraints, run from package dir:

```bash
cd packages/intentcall_platform && flutter pub publish --dry-run
```

`intentcall_gemma` is an example-only workspace package and is marked
`publish_to: none`; do not include it in the pub.dev release train.

## After publish (mcp_flutter cutover)

Status: the initial hosted cutover is complete in `mcp_flutter`.
For future IntentCall releases, update consumers only after the pub.dev package
pages exist for the full publish order above.

See the `mcp_flutter` IntentCall consumer guide (`../mcp_flutter/docs/intentcall/README.md`) and run:

```bash
just print-hosted-deps
```

Replace any temporary local-development `path:` entries in `mcp_toolkit`,
`mcp_server_dart`, and capability packages with hosted constraints for the new
version.
