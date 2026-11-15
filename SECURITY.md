# Security Policy

IntentCall is contract-tested platform infrastructure on pub.dev. Please treat
security reports as private until there is a coordinated fix or clear non-issue.

## Supported Versions

The supported security surface is the **current synchronized `intentcall_*` package train on pub.dev** plus the repository `main` branch. Older published minors are best-effort only.

`intentcall_gemma` and the workspace-only CLI surfaces are not part of the hosted pub.dev train; security issues there are still welcome, but they are not hosted package claims.

## Reporting A Vulnerability

Email `anton@xsoulspace.dev` with:

- affected package or adapter
- affected version or commit
- a minimal reproduction or proof outline
- whether the issue requires embargo before public discussion

Please do not open a public issue with exploit details, secrets, private URLs,
or customer data.

## Scope Notes

IntentCall adapters project registered Dart intents into transports and platform
artifacts. Reports are especially useful when they involve unintended execution,
unsafe argument handling, generated platform metadata, disclosure through logs or
artifacts, or a mismatch between documented support claims and actual runtime
behavior.