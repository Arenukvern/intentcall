# Security Policy

IntentCall is pre-release platform infrastructure. Please treat security reports
as private until there is a coordinated fix or clear non-issue.

## Supported Versions

The supported security surface is the current hosted `0.3.x` pre-1.0 package
train on pub.dev plus the repository `main` branch. Older pre-release trains are
best-effort only.

`intentcall_gemma` and the workspace CLI are unpublished development surfaces;
security issues there are still welcome, but they are not hosted pub.dev package
claims.

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
