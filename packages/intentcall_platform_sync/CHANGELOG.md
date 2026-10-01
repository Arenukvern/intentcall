# Changelog

## Unreleased

## [0.7.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform_sync-v0.6.0...intentcall_platform_sync-v0.7.0) (2026-10-01)


### Features

* add apple-runner-compile-check command and update Swift imports for intentcall_platform_apple in various test files ([9f22242](https://github.com/Arenukvern/intentcall/commit/9f222422bebf7fa3b01f80741ce0961a130fd278))
* add from_json_to_json and is_dart_empty_or_not dependencies, refactor JSON handling in schema and session management ([ee053c4](https://github.com/Arenukvern/intentcall/commit/ee053c426bc220a1f35574f2b952c526af8086e8))
* add intentcall_bridge package with entity open envelope support, update testing commands, and enhance documentation for new features ([cc162e0](https://github.com/Arenukvern/intentcall/commit/cc162e00a536e607b74dd83a8cd6c721b6917a8d))
* add manifest resource URI check command and enhance entity snapshot handling in example app ([e5d6f6c](https://github.com/Arenukvern/intentcall/commit/e5d6f6c08b71d7231d9f3dfddc6e9afb2abaa897))
* add mcp-flutter-apple-sync-check command and enhance README with platform sync instructions for Apple Swift integration ([b39ff0c](https://github.com/Arenukvern/intentcall/commit/b39ff0c26544de4a9d4ddf4959b22c3f0fa52837))
* add projection pipeline check command and enhance entity type descriptor handling in manifest export ([ec1fbb0](https://github.com/Arenukvern/intentcall/commit/ec1fbb07775c3125e7fc5e5446995b5ef6042ac4))
* enhance catalog management with @AgentCatalog annotation, streamline instance-bound tool integration, and update projection handling for manifest export ([37575ce](https://github.com/Arenukvern/intentcall/commit/37575ce0408fa2951275dc0fd74ef6539255e2b6))
* enhance resource URI handling by introducing protocol scheme support across agent manifest generation and related components ([e61d9d1](https://github.com/Arenukvern/intentcall/commit/e61d9d1095735bd2edd5672a9944d9a78c65baae))
* implement IntentCallNativeBridge for native handoff and update enqueue method to include fallback protocol scheme ([2c8464a](https://github.com/Arenukvern/intentcall/commit/2c8464aee49c526d5770a286b0d93c0f4eb1d269))
* implement manifest export checks and validation gates for ADR 0019 ([f91e968](https://github.com/Arenukvern/intentcall/commit/f91e96828562c4a1bc62aa91c7061f85254a2f6b))
* introduce intentcall_cli and intentcall_platform_sync packages for framework-neutral CLI and manifest handling ([ee03e70](https://github.com/Arenukvern/intentcall/commit/ee03e70de7b18e7cae3767c6c3a83b2d68af90b0))
* introduce intentcall_hooks and intentcall_bridge packages, enhance testing commands, and update manifest for new dependencies ([6272b7c](https://github.com/Arenukvern/intentcall/commit/6272b7cdf853edc9880cfc13f709a4a6a8ddd765))
* return Dart results on WebMCP, awaitApp, and Windows App Actions ([eafaaee](https://github.com/Arenukvern/intentcall/commit/eafaaee96b7c96c092d820d0292d0252cb6b9ad6))


### Bug Fixes

* **platform-sync:** catalog loader self-heals missing package resolution ([57fba5e](https://github.com/Arenukvern/intentcall/commit/57fba5e9673d519c45968c3b421d4ec46902585b))
* **platform-sync:** WebMCP interop bindings crashed app bootstrap ([4aeec90](https://github.com/Arenukvern/intentcall/commit/4aeec90e4a1edf8375286dd157192841c432b41f))

## 0.6.0 - 2026-06-29

### Added

- Dart-only platform manifest projection: generated-catalog loading
  (`CatalogLoader`), `agent_manifest.json` export with `--check`,
  WebMCP bootstrap JS, Apple/Android runner scaffolds, and Gradle/Xcode
  hook spines.
- `intentcall platform sync` (+ `--check` drift gate) and
  `apple-runner-compile-check` command support.
- Protocol-fallback invocation link records and discovery.
