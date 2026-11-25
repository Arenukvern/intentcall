# update-faq-packages

Create or refresh child package FAQs after a package gains or changes a distinct design boundary.

## Goals

- **Concise** docs; **why** in package `DESIGN_FAQ.mdx`, **how** in package `DX_FAQ.mdx`.
- Memory Palace in package DX when the API is non-trivial.
- Parent root FAQs add **router pointers only** — no copied answers.
- Verify every code block against `packages/<pkg>/lib`.

## Steps

1. Confirm the package owns distinct design (not a thin re-export). Skip federated impls that only implement umbrella contracts.
2. Add or update `packages/<pkg>/docs/DESIGN_FAQ.mdx` and `DX_FAQ.mdx` (5–15 Q&As; real facts moved from root FAQs, not duplicated).
3. Add package-root symlinks `DESIGN_FAQ.md` → `docs/DESIGN_FAQ.mdx` and `DX_FAQ.md` → `docs/DX_FAQ.mdx` for local editors.
4. Ensure `packages/<pkg>/.pubignore` lists `docs/`, `DESIGN_FAQ.md`, and `DX_FAQ.md` so pub publish/pana do not ship monorepo FAQ files.
5. Add router rows to root `docs/DESIGN_FAQ.mdx` and `docs/DX_FAQ.mdx` and the `AGENTS.md` table.
6. Run `dart pub publish --dry-run` in the package (or `just publish-dry-run`) after adding docs paths.

Thin packages: document only in root FAQs.