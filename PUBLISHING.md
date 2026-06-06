# Publishing intentcall to pub.dev

## Prerequisites

- `dart pub` logged in (`dart pub token add https://pub.dev`)
- All packages at the same semver (currently **0.1.0**)
- `just test` green in this workspace
- Release-critical worktrees clean; pub treats modified checked-in package files as publish blockers

## Order (required)

1. `intentcall_schema`
2. `intentcall_core`
3. `intentcall_mcp`, `intentcall_webmcp`, `intentcall_gemma`, `intentcall_apple`, `intentcall_android`, `intentcall_codegen`
4. `intentcall_platform` (Flutter plugin — may need `flutter pub publish`)
5. `intentcall_testing`

## Commands

```bash
# First publish: also check all package names are still available on pub.dev
just publish-preflight-first

# Later releases: check version consistency, release git cleanliness, and pub.dev credentials
just publish-preflight

# Validate all packages (CI uses this)
just publish-dry-run

# Diagnostic only while release-critical files are dirty; still fails archive/content errors
just publish-dry-run-ignore-warnings

# After credentials are configured
just publish-execute
```

For the initial `0.1.0` publish, treat `just publish-preflight-first` as the release desk:

- All `intentcall_*` package names must report available on pub.dev.
- The release-critical tree must be clean: publishable `packages/intentcall_*` files plus `tool/intentcall`, including newly added public API files such as `packages/intentcall_core/lib/intentcall_core_migration.dart`.
- `dart pub token list` must show a configured token for pub.dev.
- `just publish-dry-run` must pass from the same clean release commit before `just publish-execute`.

`just publish-dry-run-ignore-warnings` is only for diagnosing archive/content issues before the release-critical tree is clean. It must not replace the strict dry-run above.

For `intentcall_platform`, if `dart pub publish` fails on Flutter constraints, run from package dir:

```bash
cd packages/intentcall_platform && flutter pub publish --dry-run
```

## After publish (mcp_flutter cutover)

See `docs/intentcall/hosted_cutover.md` and run:

```bash
just print-hosted-deps
```

Replace `path:` entries in `mcp_toolkit`, `mcp_server_dart`, and capability packages with hosted `^0.1.0`.

Do not start the `mcp_flutter` hosted cutover until the pub.dev package pages exist for the full publish order above.
