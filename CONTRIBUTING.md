# Contributing to IntentCall

Thanks for your interest! IntentCall is a pre-release platform library. Contributions are welcome — please read this before opening a PR.

## Prerequisites

- [Dart SDK](https://dart.dev/get-dart) `^3.11.0`
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable) — required for `intentcall_platform`
- [just](https://github.com/casey/just) task runner (recommended)
- [Node.js](https://nodejs.org/) `>=18` and [pnpm](https://pnpm.io/) `>=9` — for `just docs-check` (docs.page link validation)

## Quick start

```bash
git clone https://github.com/Arenukvern/intentcall.git
cd intentcall
dart pub get
just test        # run all package tests
just analyze     # static analysis
just publish-dry-run  # pub.dev validation (no credentials needed)
```

All three must be green before opening a PR. If you changed `docs/` or `docs.json`, also run:

```bash
pnpm install   # once
just docs-check
```

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

See [docs/DX_FAQ.mdx](docs/DX_FAQ.mdx) — "How do I add a new `intentcall_*` package to the workspace?"

## Publishing

Publishing to pub.dev is maintainer-gated. Maintainers run `just publish-preflight-first` for the first publish, `just publish-preflight` for later releases, then `just publish-dry-run` before `just publish-execute`. See [PUBLISHING.md](PUBLISHING.md).

## Pre-release note

All packages are `0.1.x`. APIs may change without a semver major. See [PRE_RELEASE.md](PRE_RELEASE.md).
