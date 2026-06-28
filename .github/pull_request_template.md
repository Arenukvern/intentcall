## Summary

- 

## Scope

- Affected packages:
- ADR needed: yes / no
- Platform-support claim changed: yes / no
- Release impact: patch / minor / major / none

## Validation

- [ ] `steward probe --json --profile quick`
- [ ] `steward benchmark --scenario intentcall.adapter-contract --json`
- [ ] `just test`
- [ ] `just analyze`
- [ ] `just publish-dry-run`
- [ ] `just docs-check` if docs or `docs.json` changed

## Contributor / Governance Checks

- [ ] Contributor credit updated in `.all-contributorsrc` and `README.md` when needed
- [ ] ADR added in `docs/decisions/` for significant design forks
- [ ] No secrets, private URLs, or unpublished customer data in docs, tests, or examples
