---
status: accepted
date: 2026-06-10
decision-makers: IntentCall maintainers
consulted:
informed:
---

# Delete implemented plans after durable extraction

## Context and Problem Statement

IntentCall uses temporary specs and plans to coordinate cleanup, migration, and engineering-stewardship work. Those files are useful while work is being designed or sequenced, but they become harmful when they survive after implementation: stale plans compete with code, ADRs, docs, skills, and gates as sources of truth.

The repository needs a clear rule for what happens after a plan has been implemented or its durable knowledge has been extracted.

## Decision Drivers

* **Source-of-truth clarity** - durable behavior should live in code, ADRs, docs, skills, and checks.
* **Low documentation drag** - contributors should not maintain completed implementation scaffolding.
* **Traceability** - important decisions still need durable records.
* **Agent reliability** - agents should not follow obsolete rollout steps when current docs and gates disagree.

## Considered Options

* **Keep all completed plans as archives** - rejected because plan-shaped artifacts look actionable even when obsolete.
* **Move completed plans into an archive directory** - rejected as the default because it preserves stale procedural detail and creates another surface to curate.
* **Delete implemented plans after durable extraction** - chosen because it keeps durable knowledge in the correct owner surfaces while relying on git history for forensic traceability.

## Decision Outcome

Implemented plans and temporary specs must be deleted after their useful content has been extracted into durable surfaces:

* code and public APIs;
* accepted ADRs;
* product docs, FAQs, and package READMEs;
* standardized skills and generated skill assets;
* regression checks, benchmarks, and validation gates;
* consumer migration guides when the knowledge belongs to a consumer repository.

Archiving implemented plans is not the default. If a public durable pointer is needed, create a short consumer-facing note or ADR reference rather than preserving a plan-shaped document.

### Consequences

* Good, because current docs and gates remain easier to trust than old sequencing artifacts.
* Good, because future agents have fewer stale instructions to reconcile.
* Neutral, because reviewers must check that useful information was extracted before deletion.
* Bad, if a plan is deleted before durable extraction is complete; mitigated by linking the durable ADR, FAQ, README, skill, or gate in the cleanup change.

## Links

* [NORTH_STAR.md](/NORTH_STAR)
* [DESIGN_FAQ.md](/DESIGN_FAQ)
* [DX_FAQ.md](/DX_FAQ)
