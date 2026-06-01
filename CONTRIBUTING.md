# Contributing to IntentCall

Thanks for your interest! IntentCall is a pre-release platform library. Contributions are welcome — please read this before opening a PR.

## Prerequisites

- [Dart SDK](https://dart.dev/get-dart) `^3.11.0`
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable) — required for `intentcall_platform`
- `make` (standard on macOS/Linux)

## Quick start

```bash
git clone https://github.com/Arenukvern/intentcall.git
cd intentcall
dart pub get
make test        # run all package tests
make analyze     # static analysis
make publish-dry-run  # pub.dev validation (no credentials needed)
```

All three must be green before opening a PR.

## Conventional commits

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) for automated changelog generation via [release-please](https://github.com/googleapis/release-please).

```
feat(core): add AgentRegistry.unregister
fix(schema): validate empty AgentCallEntry name
docs: update DX_FAQ publish order
chore: bump dart_mcp to ^0.3.0
```

Breaking changes: add `!` after the type (`feat!:`) and include a `BREAKING CHANGE:` footer.

## Architecture decisions

Significant design changes (new transport, schema field change, package split) require an ADR before code lands. See [docs/decisions/README.md](docs/decisions/README.md) for the process and next number.

## Adding a package

See [DX_FAQ.md](DX_FAQ.md) — "How do I add a new `intentcall_*` package to the workspace?"

## Publishing

Publishing to pub.dev is maintainer-gated. See [PUBLISHING.md](PUBLISHING.md).

## Pre-release note

All packages are `0.1.x`. APIs may change without a semver major. See [PRE_RELEASE.md](PRE_RELEASE.md).
