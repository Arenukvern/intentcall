# Maintenance release lines (`release/*-1.2.x`)

Single-package hotfix branches carry **out-of-train** versions for one publishable
package at a time. CI uses `.release-train-maintenance.json` and divergent entries
in `.release-please-manifest.json`; `release_train.dart sync` is blocked unless
you pass `--force`.

## Workspace `intentcall_schema` 1.2.2 shim

On these branches, `packages/intentcall_schema` may be bumped to **1.2.2** in
`pubspec.yaml` only so the monorepo workspace satisfies hotfix deps
(`intentcall_schema: ^1.2.2`) while other train packages stay at **1.2.0**.

That tree is a **build shim** for CI and local workspace resolution. It is **not**
a separate schema release from this line:

- Do **not** tag `intentcall_schema-v1.2.2` from a maintenance branch commit.
- Do **not** publish `intentcall_schema` from these branches.

Consumers should use **[intentcall_schema 1.2.2 on pub.dev](https://pub.dev/packages/intentcall_schema)**.