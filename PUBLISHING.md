# Publishing intentcall to pub.dev

## Prerequisites

- `dart pub` logged in (`dart pub token add https://pub.dev`)
- All packages at the same semver (currently **0.1.0**)
- `just test` green in this workspace

## Order (required)

1. `intentcall_schema`
2. `intentcall_core`
3. `intentcall_mcp`, `intentcall_webmcp`, `intentcall_gemma`, `intentcall_apple`, `intentcall_android`, `intentcall_codegen`
4. `intentcall_platform` (Flutter plugin — may need `flutter pub publish`)
5. `intentcall_testing`

## Commands

```bash
# Validate all packages (CI uses this)
just publish-dry-run

# After credentials are configured
just publish-execute
```

For `intentcall_platform`, if `dart pub publish` fails on Flutter constraints, run from package dir:

```bash
cd intentcall/packages/intentcall_platform && flutter pub publish --dry-run
```

## After publish (mcp_flutter cutover)

See `docs/intentcall/hosted_cutover.md` and run:

```bash
just print-hosted-deps
```

Replace `path:` entries in `mcp_toolkit`, `mcp_server_dart`, and capability packages with hosted `^0.1.0`.
