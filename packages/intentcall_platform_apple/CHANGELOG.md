# Changelog

## Unreleased

## [0.7.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform_apple-v0.6.0...intentcall_platform_apple-v0.7.0) (2026-10-01)


### Features

* implement IntentCallNativeBridge for native handoff and update enqueue method to include fallback protocol scheme ([2c8464a](https://github.com/Arenukvern/intentcall/commit/2c8464aee49c526d5770a286b0d93c0f4eb1d269))
* return Dart results on WebMCP, awaitApp, and Windows App Actions ([eafaaee](https://github.com/Arenukvern/intentcall/commit/eafaaee96b7c96c092d820d0292d0252cb6b9ad6))


### Bug Fixes

* gitignore ([7c29a40](https://github.com/Arenukvern/intentcall/commit/7c29a403102079c0b68c9d809eccd7e9eb67c182))
* **platform-apple:** registerAwaitingApi cannot be public ([d45459e](https://github.com/Arenukvern/intentcall/commit/d45459e88840b0909699b4bcd2f1df8a6811c15c))

## 0.6.0

### Features

- Federated Apple (iOS/macOS) implementation package with shared Darwin SPM
  sources for `intentcall_platform`.
