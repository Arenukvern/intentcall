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
| Which audience / setup lane? | [docs/start_here/audiences.mdx](docs/start_here/audiences.mdx) |
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
6. Apple generated Swift compile proof runs in the mcp_flutter dogfood repo (`tool/contracts/check_apple_runner_compile.sh`, wired into `make check-contracts`). From agentkit with a sibling checkout: `just apple-runner-compile-check`.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **intentcall** (3228 symbols, 7516 relationships, 230 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/intentcall/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/intentcall/context` | Codebase overview, check index freshness |
| `gitnexus://repo/intentcall/clusters` | All functional areas |
| `gitnexus://repo/intentcall/processes` | All execution flows |
| `gitnexus://repo/intentcall/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
