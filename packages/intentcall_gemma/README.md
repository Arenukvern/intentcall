> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_gemma

[![publish: none](https://img.shields.io/badge/pub.dev-unpublished-lightgrey)](https://github.com/Arenukvern/intentcall/tree/main/packages/intentcall_gemma)
[![repository](https://img.shields.io/badge/repo-intentcall-blue)](https://github.com/Arenukvern/intentcall)

Example-only `GemmaPublishAdapter` for on-device Gemma experiments.

This package is intentionally not published to pub.dev. It remains in the
workspace as executable reference code for mapping IntentCall tool registrations
into Gemma-style function definitions, but it is not a supported product adapter
or part of the hosted IntentCall package train.

Use it as a small implementation sketch when building a concrete on-device
Gemma bridge. Product packages should copy the relevant adapter shape into their
own runtime integration and own the model/runtime policy there.
