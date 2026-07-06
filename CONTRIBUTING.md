# Contributing to IntentCall

Thanks for your interest! IntentCall is a pre-release platform library. Contributions are welcome — please read this before opening a PR.

## Prerequisites

- [Dart SDK](https://dart.dev/get-dart) `^3.12.0`
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

Agent/operator preflight starts with the declared Steward surface:

```bash
steward doctor --json
steward actions list --json
steward action inspect intentcall.validate --json
steward action inspect intentcall.adapter-contract-test --json
steward probe --json --profile quick
steward benchmark --scenario intentcall.adapter-contract --json
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

## Contributors

IntentCall uses [all-contributors](https://allcontributors.org/) for visible
credit. The canonical roster is [`.all-contributorsrc`](.all-contributorsrc),
and the rendered table lives in [README.md](README.md).

To credit a contributor from a PR:

```bash
npx all-contributors-cli add <github-login> code,doc
npx all-contributors-cli generate
```

Commit both `.all-contributorsrc` and `README.md`. Pick contribution types that
describe what happened, such as `code`, `doc`, `bug`, `infra`, `security`,
`maintenance`, `research`, `tutorial`, or `userTesting`.

## Security

Do not put secrets, private URLs, tokens, or unpublished customer data in docs,
ADRs, tests, issues, or PRs. Report vulnerabilities privately through
[SECURITY.md](SECURITY.md).

## Publishing

Publishing to pub.dev is maintainer-gated. Maintainers normally merge the Release Please PR and let tag-triggered GitHub Actions publish through pub.dev automated publishing. `just publish-dry-run` and tag dry-runs are preflight checks; manual execute commands are recovery-only. See [PUBLISHING.md](PUBLISHING.md).

## Pre-release note

The hosted packages are on the current `0.3.x` pre-1.0 train. APIs may change
without a semver major. See [PRE_RELEASE.md](PRE_RELEASE.md).
