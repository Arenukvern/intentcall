# Changelog

## Unreleased

## [1.0.0](https://github.com/Arenukvern/intentcall/compare/intentcall_cli-v0.7.0...intentcall_cli-v1.0.0) (2026-10-01)


### Miscellaneous Chores

* **intentcall_cli:** Synchronize intentcall package train versions

## [0.7.0](https://github.com/Arenukvern/intentcall/compare/intentcall_cli-v0.6.0...intentcall_cli-v0.7.0) (2026-10-01)


### Features

* **acp:** AcpAgentProvider composition adapter; verified process stops ([247f186](https://github.com/Arenukvern/intentcall/commit/247f186574a69b6df1cc768e416d9d16f951fc33))
* add manifest resource URI check command and enhance entity snapshot handling in example app ([e5d6f6c](https://github.com/Arenukvern/intentcall/commit/e5d6f6c08b71d7231d9f3dfddc6e9afb2abaa897))
* add projection pipeline check command and enhance entity type descriptor handling in manifest export ([ec1fbb0](https://github.com/Arenukvern/intentcall/commit/ec1fbb07775c3125e7fc5e5446995b5ef6042ac4))
* enhance catalog management with @AgentCatalog annotation, streamline instance-bound tool integration, and update projection handling for manifest export ([37575ce](https://github.com/Arenukvern/intentcall/commit/37575ce0408fa2951275dc0fd74ef6539255e2b6))
* implement manifest export checks and validation gates for ADR 0019 ([f91e968](https://github.com/Arenukvern/intentcall/commit/f91e96828562c4a1bc62aa91c7061f85254a2f6b))
* introduce intentcall_cli and intentcall_platform_sync packages for framework-neutral CLI and manifest handling ([ee03e70](https://github.com/Arenukvern/intentcall/commit/ee03e70de7b18e7cae3767c6c3a83b2d68af90b0))
* introduce intentcall_hooks and intentcall_bridge packages, enhance testing commands, and update manifest for new dependencies ([6272b7c](https://github.com/Arenukvern/intentcall/commit/6272b7cdf853edc9880cfc13f709a4a6a8ddd765))
* update pubspec.lock with new dependencies and versions; enhance documentation for instance-bound tools and manifest export ([d4d6fd1](https://github.com/Arenukvern/intentcall/commit/d4d6fd18cd1c82e4d67a2eba478fe60f93d68f03))


### Bug Fixes

* **cli:** declare intentcall_codegen dev dependency ([15d1091](https://github.com/Arenukvern/intentcall/commit/15d10918d3375dbad2ea94c3daebdc5d5f4b6b39))

## 0.6.0

### Added

- Initial train snapshot: framework-neutral IntentCall CLI —
  `manifest export` (with `--check` drift gate), `platform sync`,
  `link discover` / `link call`, `mcp serve`, and Apple AppIntents
  testing helpers.
