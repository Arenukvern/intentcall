# IntentCall — Agent Map

IntentCall is a **transport-agnostic agent intent platform** for Dart/Flutter.
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

- **Do NOT run bash scripts manually.** You must execute workflows via `steward mcp`. Run `steward_run_pipeline_test`, `steward_run_pipeline_analyze`, and `steward_run_pipeline_publish-dry-run` before opening a PR.
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
1. **You MUST attach to `steward mcp`**. The `steward.yaml` configuration defines the available pipeline tools (`test`, `analyze`, `publish-dry-run`) and documentation resources. Do not attempt to guess bash commands.
2. Fetch required documentation directly via the `steward_read_governance` tool or `steward://docs/` URIs (e.g. read the Ethics Charter).
3. The repository utilizes standardized agent skills under `.agents/skills/` and its own distributable skills under `skills/`. Use the `steward bundle` command to pack skills.
4. Run `steward_run_pipeline_validate` (or `steward validate` natively) to automatically validate your skills and brand compliance before committing.
