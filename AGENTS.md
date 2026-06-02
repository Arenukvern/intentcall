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
| Where is the full doc map? | [docs/start_here/docs_map.md](docs/start_here/docs_map.md) |
| What does this repo own? | [docs/NORTH_STAR.md](docs/NORTH_STAR.md) |
| Why is it built this way? | [DESIGN_FAQ.md](DESIGN_FAQ.md) |
| How do I use / extend it? | [DX_FAQ.md](DX_FAQ.md) |
| Why was X decided? | [docs/decisions/](docs/decisions/README.md) |
| How do I contribute? | [CONTRIBUTING.md](CONTRIBUTING.md) |
| How do I publish to pub.dev? | [PUBLISHING.md](PUBLISHING.md) |
| What is the pre-release status? | [PRE_RELEASE.md](PRE_RELEASE.md) |
| What skills are installed? | [.agents/skills/](.agents/skills/) |

---

## Non-negotiables

- Run `just test && just analyze && just publish-dry-run` before opening a PR.
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
