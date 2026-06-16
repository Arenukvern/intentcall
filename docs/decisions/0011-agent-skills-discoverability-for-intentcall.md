---
status: accepted
date: 2026-06-02
decision-makers: IntentCall maintainers, Antigravity
consulted:
informed:
---

# Agent Skills Discoverability and Custom Skills for IntentCall

## Context and Problem Statement

IntentCall is a platform library. While it has successfully adopted the **Skill Steward** meta-harness (which installs 15 meta-skills like `adr-records` or `north-star-governance` under `.agents/skills/` to manage this repository), it does not define or expose any **domain-specific developer skills** for agents or developers who want to integrate with or build on top of IntentCall. 

Currently, visiting AI agents have to read raw codebase FAQs or source files without structured, step-by-step procedural guidelines (e.g., how to register intents, how to write an adapter). Furthermore, there is no marketplace manifest (`.claude-plugin/`, `.cursor-plugin/`, or `skills.sh.json`) to register these skills, making them undiscoverable by agentic package managers (like `npx skills`).

We need a clear strategy to:
1. Define IntentCall-specific developer skills.
2. Structure and publish them so they are discoverable via `npx skills` and agent-specific marketplaces.
3. Integrate skill listing into the repository's task runner.

## Decision Drivers

* **Agent Legibility** — Make it extremely easy for incoming agents to understand *how* to write adapters and register tools.
* **Standards Conformity** — Align with the `concept-doc-store` and `plugin-marketplace-setup` specifications.
* **Separation of Concerns** — Distinguish meta-skills (managing the repo) from domain-skills (using the library).
* **Discoverability** — Ensure skills are registerable on `skills.sh` and discoverable locally via CLI tools.

## Considered Options

* **Option 1: Rely solely on DESIGN_FAQ and DX_FAQ** — Minimal overhead, but lacks procedural step-by-step instructions for agents, which can lead to adapter drift.
* **Option 2: Add custom skills in `skills/` with a marketplace manifest** — chosen: defines `skills/register-intents/SKILL.md` and `skills/write-adapter/SKILL.md`, registers them in `skills.sh.json`, and exposes them for `npx skills add Arenukvern/intentcall`.

## Decision Outcome

Chosen option: **Option 2**. We will introduce IntentCall-specific developer skills, structure them under the root `skills/` directory, register them in `skills.sh.json`, and link them in our developer router documents.

### Proposed Structure

```text
/
├── skills/
│   ├── register-intents/
│   │   └── SKILL.md          # How to register tool/resource intents
│   └── write-adapter/
│       └── SKILL.md          # How to write a custom transport adapter
├── skills.sh.json            # Registry for skills.sh leaderboard / indexer
├── .agents/skills/           # Legacy/Meta-skills (unchanged)
```

### Consequences

* Good, because agents will instantly discover step-by-step guidelines for building adapters and registering intents.
* Good, because `npx skills add Arenukvern/intentcall --skill write-adapter` becomes functional.
* Neutral, because it requires ongoing documentation maintenance alongside core code changes.

### Follow-up

1. Create `skills/register-intents/SKILL.md`.
2. Create `skills/write-adapter/SKILL.md`.
3. Create `skills.sh.json` at root.
4. Add `just list-skills` target to `justfile`.
5. Update `docs/decisions/README.md` index.

## Links

* [Skill Steward — plugin-marketplace-setup](../../.agents/skills/plugin-marketplace-setup/SKILL.md)
* [Skill Steward — create-skill](../../.agents/skills/create-skill/SKILL.md)
