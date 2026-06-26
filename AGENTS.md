# IntentCall — Agent Map

**IntentCall** lets Dart/Flutter apps define agent-callable actions once in `AgentRegistry`, then project them to MCP, WebMCP, shortcuts, and deep links — without rewriting per transport. **Building a Flutter app?** Start with [mcp_flutter](https://github.com/Arenukvern/mcp_flutter). **Building adapters or platform projection?** You're in the right repo.

Published docs: [docs.page/Arenukvern/intentcall](https://docs.page/Arenukvern/intentcall) · Full router: [docs/start_here/docs_map.mdx](docs/start_here/docs_map.mdx)

Install Skill Steward meta-skills for this repo:

```bash
npx skills add arenukvern/skill_steward
```

---

## Documentation router

| Question | Go to |
|---|---|
| Where is the full doc map? | [docs/start_here/docs_map.mdx](docs/start_here/docs_map.mdx) |
| What does this repo own? | [docs/NORTH_STAR.mdx](docs/NORTH_STAR.mdx) |
| Why is it built this way? | [docs/DESIGN_FAQ.mdx](docs/DESIGN_FAQ.mdx) |
| How do I use / extend it? | [docs/DX_FAQ.mdx](docs/DX_FAQ.mdx) |
| Why was X decided? | [docs/decisions/README.md](docs/decisions/README.md) |
| How do I contribute? | [CONTRIBUTING.md](CONTRIBUTING.md) |
| How do I publish to pub.dev? | [PUBLISHING.md](PUBLISHING.md) |
| What is the pre-release status? | [PRE_RELEASE.md](PRE_RELEASE.md) |
| What skills are installed? | [.agents/skills/](.agents/skills/) |

---

## Non-negotiables

- Start agent work with `steward doctor --json`, `steward actions list --json`, and `steward action inspect <id> --json` before running declared actions.
- Use `steward benchmark --scenario intentcall.adapter-contract --json` for the first Steward dogfood scenario.
- Do not use legacy `steward mcp` pipeline execution or `steward_run_pipeline_*` tools for v1 contracts.
- Significant design forks → ADR in `docs/decisions/` before coding.
- No secrets, tokens, or private URLs in ADRs or docs.
- Plan files are temporary — extract durable knowledge to ADR/FAQ then delete.
- Adapter authors: read `intentcall_mcp` as the reference implementation first.

---

## Install paths

| Agent / Tool | Skills location |
|---|---|
| Antigravity / Claude Code | `.agents/skills/` |
| Cursor | `.cursor/skills/` (if using Cursor) |
| Codex | `.agents/skills/` |

---

Skill authoring detail → [.agents/skills/create-skill/SKILL.md](.agents/skills/create-skill/SKILL.md)

## Governance & Skill Steward

This repository strictly adheres to the Cascading Agent Surface architecture governed by **Skill Steward**.
When writing code, documentation, or planning features:
1. Run `steward doctor --json` to inspect the v1 contract without executing repository actions.
2. Run `steward actions list --json` and inspect intended actions with `steward action inspect <id> --json`.
3. Run `steward probe --json --profile quick` for the safe first pass.
4. Run `steward benchmark --scenario intentcall.adapter-contract --json` for the first dogfood loop.
5. The repository uses standardized agent skills under `.agents/skills/` and distributable skills under `skills/`; skills remain installed separately from hook/plugin wiring.
