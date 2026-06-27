# IntentCall

[![maintained with Skill Steward](https://raw.githubusercontent.com/Arenukvern/skill_steward/main/docs/brand/assets/svg/badge-solid.svg)](https://github.com/Arenukvern/skill_steward)

> **Pre-release train** — Contract-tested pre-1.0 platform infrastructure. APIs may change without notice. **Not for production claims without app/runtime proof.** See [PRE_RELEASE.md](PRE_RELEASE.md).

*Register intents. Call them everywhere.*

Transport-agnostic agent intent platform for Dart/Flutter: define intent truth once in `AgentRegistry`, then project it into the strongest available surface: MCP/WebMCP, native action metadata where supported, assistant/shortcut fulfillment, and canonical deep-link fallback where native support is incomplete. Extracted from [mcp_flutter](https://github.com/Arenukvern/mcp_flutter).

![Watercolor comic explainer showing IntentCall as four steps: write one intent, register it once, project it to Web agents desktop OS shortcuts and deep links, then people and agents use it.](docs/assets/intentcall-watercolor-explainer-v2.png)

Conceptual map: write one Dart intent, register it once, project it to useful surfaces, then people and agents use it.

**Start here:** [How it works](docs/start_here/how_it_works.mdx) · [Choose your path](docs/start_here/choose_your_path.mdx) · [Platform support](docs/start_here/platform_support.mdx) · [Roadmap](docs/start_here/roadmap.mdx)

**Charter:** [docs/NORTH_STAR.mdx](docs/NORTH_STAR.mdx) · **Agent map:** [AGENTS.md](AGENTS.md) · **Docs site:** [docs.page/Arenukvern/intentcall](https://docs.page/Arenukvern/intentcall)
**Why / how:** [docs/DESIGN_FAQ.mdx](docs/DESIGN_FAQ.mdx) · [docs/DX_FAQ.mdx](docs/DX_FAQ.mdx) · [Decisions](docs/decisions/) · [CONTRIBUTING.md](CONTRIBUTING.md)

GitHub: [Arenukvern/intentcall](https://github.com/Arenukvern/intentcall)

## Ecosystem

| Repo | Role |
|---|---|
| **IntentCall** (this repo) | Platform layer — registry + adapters |
| **[mcp_flutter](https://github.com/Arenukvern/mcp_flutter)** | Product harness — `mcp_toolkit`, `flutter-mcp-toolkit` CLI |
| **[Skill Steward](https://github.com/Arenukvern/skill_steward)** | Meta-layer — agent skills governance |

## Packages

| Package | Role |
|---------|------|
| `intentcall_schema` | Wire types, validation, `AgentResult` |
| `intentcall_core` | Registry, runtime, `AgentCallEntry`, and neutral tool/resource registration vocabulary |
| `intentcall_session` | Runtime session lifecycle, persisted session state, snapshots, and registry execution inside a session |
| `intentcall_mcp` | MCP publish adapter and MCP mapping (`dart_mcp`) |
| `intentcall_webmcp` | WebMCP hot-sync adapter |
| `intentcall_platform` | Native/web emitters, protocol fallback artifacts, and Flutter plugin |
| `intentcall_codegen` | Optional `@AgentTool` codegen |
| `intentcall_testing` | Contract / invoke test helpers |
| `intentcall_gemma` / `intentcall_apple` / `intentcall_android` | Optional experimental surface adapters |

Platform support is tiered during the current pre-1.0 train: current code covers contract-tested MCP adapters, Dart-first WebMCP emitter/bootstrap helpers, Apple App Intents dispatch wrappers, Android shortcut/deep-link artifacts, Windows protocol activation artifacts, and Linux `x-scheme-handler` artifacts. Apple App Intents currently launch/wake the app and dispatch an invocation envelope for Dart execution; they do not claim app-extension-hosted Dart execution or native background business logic. Android AppFunctions, richer Android App Actions capability generation, Windows App Actions / Agent Launchers, and AAIF ecosystem alignment are roadmap targets unless documented otherwise. See [Platform support](docs/start_here/platform_support.mdx) for evidence levels and non-claims.

## Agent Skills

We provide custom agent skills to assist in developing with and extending IntentCall:

| Skill | Description | Install command |
|---|---|---|
| [register-intents](skills/register-intents/SKILL.md) | Guide to manual and codegen intent registration. | `npx skills add Arenukvern/intentcall --skill register-intents` |
| [write-adapter](skills/write-adapter/SKILL.md) | Guide to implementing custom platform/transport adapters. | `npx skills add Arenukvern/intentcall --skill write-adapter` |

Repository management is guided by [Skill Steward](https://github.com/Arenukvern/skill_steward) meta-skills (installed in `.agents/skills/`).

## Development

Human local setup:

```bash
dart pub get
just test
just analyze
just publish-dry-run   # pub.dev dry-run (all packages)
```

Agent/operator first run:

```bash
steward doctor --json
steward actions list --json
steward action inspect intentcall.validate --json
steward probe --json --profile quick
steward benchmark --scenario intentcall.adapter-contract --json
```

Release maintainers use Release Please. Merging the release PR creates package tags; tag-triggered GitHub Actions publishes through pub.dev automated publishing.

See [docs/DX_FAQ.mdx](docs/DX_FAQ.mdx) for detailed workflows.

## Git history

This repository starts with a **fresh history** (2026-05-28). Packages were developed inside `mcp_flutter` until Phase 7 extract; `git filter-repo` / subtree split was deferred to avoid timebox risk. Use `mcp_flutter` git log before the extract commit for prior package history.

## Flutter MCP Toolkit

App authors should prefer **`mcp_toolkit`** + `flutter-mcp-toolkit` CLI. IntentCall packages are for platform work and advanced integration.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All PRs must pass `just test && just analyze && just publish-dry-run`.

## Publishing

See [PUBLISHING.md](PUBLISHING.md). The normal path is Release Please merge -> tag-triggered GitHub Actions publish; manual publish commands are recovery-only.
