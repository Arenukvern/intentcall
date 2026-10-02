# Changelog

## Unreleased

### Features

- Add neutral `AgentEntityRef` and `AgentEntitySnapshot` schema models for
  app-owned typed entity snapshots, including display, keyword, link, freshness,
  version, and deletion metadata.

## [1.2.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v1.0.0...intentcall_schema-v1.2.0) (2026-10-02)


### Miscellaneous Chores

* **intentcall_schema:** Synchronize intentcall package train versions

## [1.0.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.7.0...intentcall_schema-v1.0.0) (2026-10-01)


### Bug Fixes

* **schema:** enforce JSON-Schema array vocabulary in validator and coercion ([4366745](https://github.com/Arenukvern/intentcall/commit/4366745dad4a15badf24c42ef6d5e958d2c16335))

## [0.7.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.6.0...intentcall_schema-v0.7.0) (2026-10-01)


### Features

* add from_json_to_json and is_dart_empty_or_not dependencies, refactor JSON handling in schema and session management ([ee053c4](https://github.com/Arenukvern/intentcall/commit/ee053c426bc220a1f35574f2b952c526af8086e8))
* add intentcall_bridge package with entity open envelope support, update testing commands, and enhance documentation for new features ([cc162e0](https://github.com/Arenukvern/intentcall/commit/cc162e00a536e607b74dd83a8cd6c721b6917a8d))
* add projection pipeline check command and enhance entity type descriptor handling in manifest export ([ec1fbb0](https://github.com/Arenukvern/intentcall/commit/ec1fbb07775c3125e7fc5e5446995b5ef6042ac4))
* enhance resource URI handling by introducing protocol scheme support across agent manifest generation and related components ([e61d9d1](https://github.com/Arenukvern/intentcall/commit/e61d9d1095735bd2edd5672a9944d9a78c65baae))
* introduce intentcall_cli and intentcall_platform_sync packages for framework-neutral CLI and manifest handling ([ee03e70](https://github.com/Arenukvern/intentcall/commit/ee03e70de7b18e7cae3767c6c3a83b2d68af90b0))
* update documentation structure and enhance intentcall_schema references across various files ([e2e31f2](https://github.com/Arenukvern/intentcall/commit/e2e31f2fd32603c274b65efd177623b37d40ea27))

## [0.6.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.5.0...intentcall_schema-v0.6.0) (2026-06-29)


### Miscellaneous Chores

* **intentcall_schema:** Synchronize intentcall package train versions

## [0.5.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.4.0...intentcall_schema-v0.5.0) (2026-06-29)


### Features

* add release-ready typed entity projections ([b2119b1](https://github.com/Arenukvern/intentcall/commit/b2119b14a1e157129ead9cf18e795bdde1ea2cd3))
* add release-ready typed entity projections ([f7b9546](https://github.com/Arenukvern/intentcall/commit/f7b9546d291f7206c3be0ea71302144de6b836eb))

## [0.4.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.3.1...intentcall_schema-v0.4.0) (2026-06-28)


### Features

* **intentcall_platform:** add Apple inline runtime proof scaffolds ([a09f403](https://github.com/Arenukvern/intentcall/commit/a09f40326233e04e28901e2d06c7649b039a54d8))
* **intentcall_platform:** add Apple inline runtime proof scaffolds ([f9a6221](https://github.com/Arenukvern/intentcall/commit/f9a6221a0e1ff49a87dc670d6a0dbb805931522b))

## [0.3.1](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.3.0...intentcall_schema-v0.3.1) (2026-06-27)


### Miscellaneous Chores

* **intentcall_schema:** Synchronize intentcall package train versions

## [0.3.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.2.1...intentcall_schema-v0.3.0) (2026-06-26)


### Features

* add Dart-first native invocation surfaces ([4d5eaae](https://github.com/Arenukvern/intentcall/commit/4d5eaae19f31e2c5acba6f40280111766710c396))

## [0.2.1](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.2.0...intentcall_schema-v0.2.1) (2026-06-23)


### Miscellaneous Chores

* **intentcall_schema:** Synchronize intentcall package train versions

## [0.2.0](https://github.com/Arenukvern/intentcall/compare/intentcall_schema-v0.1.0...intentcall_schema-v0.2.0) (2026-06-22)


### Bug Fixes

* lints ([fc01a96](https://github.com/Arenukvern/intentcall/commit/fc01a963d1258d175314fa5838c7969386d3175d))

## 0.1.0

- First pre-release of IntentCall schema primitives.
- Includes `AgentResult`, wire argument helpers, JSON Schema validation, schema
  coercion, and result envelope helpers.
