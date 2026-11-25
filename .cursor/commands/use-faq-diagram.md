# use-faq-diagram

Cross-check FAQs against architecture diagrams and package boundaries.

## Goals

- Same as **update-faq**: concise docs, why in DESIGN, how in DX, Memory Palace for DX, no duplication, verify against code.
- Ensure FAQ **locations** match how the system is drawn: registry center, adapters on the edge, platform projection as cache not second catalog.

## Steps

1. Open `docs/start_here/how_it_works.mdx`, `docs/NORTH_STAR.mdx`, and relevant ADRs under `docs/decisions/`.
2. Walk root `DESIGN_FAQ.mdx` — every architectural Q should map to a box or arrow in the diagrams (registry, schema, session, adapters, platform sync).
3. Walk root `DX_FAQ.mdx` Memory Palace sections — each emoji location should correspond to a developer task (getting started, adapter, publish), not a duplicate of DESIGN rationale.
4. For package FAQs, confirm parent FAQs only **route** (`packages/<pkg>/docs/DX_FAQ.mdx`) and do not restate child answers.
5. Fix drift: compress long DESIGN answers; move procedural detail to package DX FAQs; link ADRs for proof tiers and platform support claims.