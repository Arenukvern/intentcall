# Publishing intentcall to pub.dev

Status: all publishable `intentcall_*` packages should move together on the
current pre-1.0 train. Use this runbook for normal
tag-triggered releases; keep first-publish and manual execute commands only as
historical or recovery guidance.

## Automatic release and publish flow

IntentCall uses manifest-driven Release Please plus tag-triggered pub.dev
publishing:

1. Conventional commits land on `main`.
2. `.github/workflows/release-please.yml` opens or updates one release PR from
   `release-please-config.json` and `.release-please-manifest.json`.
3. The Release Please config links every publishable `intentcall_*` component
   into one package train, including `intentcall_session`, so versions remain
   synchronized.
4. Merging the release PR creates component tags such as
   `intentcall_core-v0.2.1`.
5. `.github/workflows/pub_publish.yml` runs for each `intentcall_*-v*` tag and
   publishes the package named by that tag. The workflow is skip-existing safe,
   so rerunning a tag does not republish an already visible package version.

This mirrors the `mcp_flutter` release pattern: Release Please owns version and
changelog generation, while the native repo publish script owns pub.dev
preflight and publishing.

Release PR titles must keep the release-please parseable grouped shape generated
from `group-pull-request-title-pattern`: `chore${scope}: release intentcall
package train`. Do not retitle release PRs away from that shape; Release Please
can merge such PRs but then refuse to create tags.

## Required GitHub and pub.dev configuration

- Add a repository secret named `RELEASE_PLEASE_TOKEN` with permission to create
  releases and tags that trigger follow-up workflows. If Release Please falls
  back to `GITHUB_TOKEN`, GitHub can suppress the downstream tag-triggered
  publish workflow.
- Create a GitHub Actions environment named `pub.dev`. Add required reviewers
  there if release publishing should be gated.
- On pub.dev, enable automated publishing for every existing package in the
  train. Use repository `Arenukvern/intentcall`, environment `pub.dev`, and the
  package-specific tag pattern:

```text
intentcall_schema-v{{version}}
intentcall_core-v{{version}}
intentcall_session-v{{version}}
intentcall_mcp-v{{version}}
intentcall_webmcp-v{{version}}
intentcall_apple-v{{version}}
intentcall_android-v{{version}}
intentcall_codegen-v{{version}}
intentcall_platform-v{{version}}
intentcall_testing-v{{version}}
```

No long-lived pub.dev token is required in GitHub Actions. The publish workflow
uses GitHub OIDC through `dart-lang/setup-dart`.

## Prerequisites

- `dart pub` logged in (`dart pub token add https://pub.dev`)
- All packages at the same semver for the release train
- `just test` green in this workspace
- Release-critical worktrees clean; pub treats modified checked-in package files as publish blockers

## Order (required)

1. `intentcall_schema`
2. `intentcall_core`
3. `intentcall_session`
4. `intentcall_mcp`, `intentcall_webmcp`, `intentcall_apple`, `intentcall_android`, `intentcall_codegen`
5. `intentcall_platform_sync`, `intentcall_cli`
6. `intentcall_platform` (Flutter plugin — may need `flutter pub publish`)
7. `intentcall_testing`

## Commands

```bash
# Historical first-publish check: only for brand-new package names
just publish-preflight-first

# Later releases: check version consistency, release git cleanliness, and pub.dev credentials
just publish-preflight

# Validate all packages (CI uses this)
just publish-dry-run

# Validate one package tag the way automated publishing does
just publish-tag-dry-run intentcall_session-v0.2.1

# Diagnostic only while release-critical files are dirty; still fails archive/content errors
just publish-dry-run-ignore-warnings

# Recovery-only: after credentials are configured and automated publishing is unavailable
just publish-execute

# CI normally runs this from .github/workflows/pub_publish.yml on tag push
just publish-tag-execute intentcall_session-v0.2.1
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
