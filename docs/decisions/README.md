# Architecture Decision Records

Architecture Decision Records (ADRs) for IntentCall.
Format: [MADR](https://adr.github.io/madr/) — see any existing ADR for the template.

Next ADR number: **0019**

---

## Index

| ADR | Status | Title | Date |
|-----|--------|-------|------|
| [0010](0010-adopt-intentcall-product-name.md) | accepted | Adopt IntentCall as the public product name | 2026-05-29 |
| [0011](0011-agent-skills-discoverability-for-intentcall.md) | accepted | Agent Skills Discoverability and Custom Skills for IntentCall | 2026-06-02 |
| [0012](0012-adopt-platform-support-tiers.md) | accepted | Adopt platform support tiers for IntentCall | 2026-06-10 |
| [0013](0013-delete-implemented-plans-after-durable-extraction.md) | accepted | Delete implemented plans after durable extraction | 2026-06-10 |
| [0014](0014-own-runtime-sessions-in-intentcall.md) | accepted | Own runtime sessions in IntentCall | 2026-06-22 |
| [0015](0015-dart-first-native-bridge.md) | accepted | Dart-first Native Bridge for Platform Surfaces | 2026-06-26 |
| [0016](0016-dispatch-mode-handoff-contract.md) | accepted | Dispatch Mode Handoff Contract | 2026-06-28 |
| [0017](0017-apple-inline-runtime-tracks.md) | accepted | Apple Inline Runtime Tracks | 2026-06-28 |
| [0018](0018-additive-actions-typed-entities-indexing-lifecycle.md) | accepted | Additive Actions, Typed Entities, and Indexing Lifecycle | 2026-06-29 |

---

## Adding a new ADR

1. Copy the frontmatter from an existing ADR.
2. Name the file `NNNN-kebab-case-title.md` using the next number above.
3. Add a row to the index table above (newest at bottom).
4. Link the ADR from the relevant code, PR, or `DESIGN_FAQ.md` entry.
5. Increment "Next ADR number" above.
