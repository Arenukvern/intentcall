# update-faq

After a code or API change, sync living documentation with the codebase.

## Goals

- **Concise** Q&A — DESIGN answers ≤3 sentences; DX one pattern per Memory Palace location.
- **Why** in `DESIGN_FAQ.mdx` (root or `packages/<pkg>/docs/`).
- **How** in `DX_FAQ.mdx` with copy-paste blocks validated against current sources.
- **No duplication** — link to ADRs and child package FAQs instead of repeating.

## Steps

1. Classify the change: architecture/trade-off → DESIGN; public API/workflow → DX; new package boundary → child FAQ pair + router lines in parent FAQs.
2. Read the code paths you are documenting; grep for the public types and commands you cite.
3. Edit existing Q&As before adding new ones; remove or supersede stale entries (especially pre-1.0 wording now that `intentcall_*` is 1.x on pub.dev).
4. Update `AGENTS.md` router rows only when paths or package ownership change.
5. Run `pnpm install && just docs-check` when `docs/` or `docs.json` changed; run `dart analyze` if examples import package APIs.

Follow `.cursor/rules/faq_usage.mdc` for which file to touch.