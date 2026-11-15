> ⚠️ **Published package train** — Hosted `intentcall_*` packages follow semver 1.x on pub.dev (breaking changes require a major). Not for production claims without app/runtime proof. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).

# intentcall_platform_apple

Federated Apple (iOS/macOS) implementation for
[`intentcall_platform`](https://pub.dev/packages/intentcall_platform).

Uses `sharedDarwinSource` with SPM under
`darwin/intentcall_platform_apple/`. Dart API stays in the umbrella package —
this package is native-only.

App authors depend on `intentcall_platform`; this package is endorsed and
resolved automatically.
