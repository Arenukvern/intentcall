# Changelog

## [0.7.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.6.0...intentcall_codegen-v0.7.0) (2026-10-01)


### Features

* add from_json_to_json and is_dart_empty_or_not dependencies, refactor JSON handling in schema and session management ([ee053c4](https://github.com/Arenukvern/intentcall/commit/ee053c426bc220a1f35574f2b952c526af8086e8))
* add manifest resource URI check command and enhance entity snapshot handling in example app ([e5d6f6c](https://github.com/Arenukvern/intentcall/commit/e5d6f6c08b71d7231d9f3dfddc6e9afb2abaa897))
* add mcp-flutter-apple-sync-check command and enhance README with platform sync instructions for Apple Swift integration ([b39ff0c](https://github.com/Arenukvern/intentcall/commit/b39ff0c26544de4a9d4ddf4959b22c3f0fa52837))
* add projection pipeline check command and enhance entity type descriptor handling in manifest export ([ec1fbb0](https://github.com/Arenukvern/intentcall/commit/ec1fbb07775c3125e7fc5e5446995b5ef6042ac4))
* enhance catalog management with @AgentCatalog annotation, streamline instance-bound tool integration, and update projection handling for manifest export ([37575ce](https://github.com/Arenukvern/intentcall/commit/37575ce0408fa2951275dc0fd74ef6539255e2b6))
* enhance example app with detailed documentation on catalog and runtime registration, improve instance-bound tool integration ([2e4b137](https://github.com/Arenukvern/intentcall/commit/2e4b137b8ef0b13a38f43be91d8a831d1a3191ab))
* implement manifest export checks and validation gates for ADR 0019 ([f91e968](https://github.com/Arenukvern/intentcall/commit/f91e96828562c4a1bc62aa91c7061f85254a2f6b))
* introduce intentcall_cli and intentcall_platform_sync packages for framework-neutral CLI and manifest handling ([ee03e70](https://github.com/Arenukvern/intentcall/commit/ee03e70de7b18e7cae3767c6c3a83b2d68af90b0))
* introduce intentcall_hooks and intentcall_bridge packages, enhance testing commands, and update manifest for new dependencies ([6272b7c](https://github.com/Arenukvern/intentcall/commit/6272b7cdf853edc9880cfc13f709a4a6a8ddd765))
* refine @AgentCatalog usage with static field support, enhance documentation on catalog placement, and improve projection handling in examples ([d373c74](https://github.com/Arenukvern/intentcall/commit/d373c744150cdde56e2d4844211e25362f3d6723))
* return Dart results on WebMCP, awaitApp, and Windows App Actions ([eafaaee](https://github.com/Arenukvern/intentcall/commit/eafaaee96b7c96c092d820d0292d0252cb6b9ad6))
* update pubspec.lock with new dependencies and versions; enhance documentation for instance-bound tools and manifest export ([d4d6fd1](https://github.com/Arenukvern/intentcall/commit/d4d6fd18cd1c82e4d67a2eba478fe60f93d68f03))

## [0.6.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.5.0...intentcall_codegen-v0.6.0) (2026-06-29)


### Miscellaneous Chores

* **intentcall_codegen:** Synchronize intentcall package train versions

## [0.5.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.4.0...intentcall_codegen-v0.5.0) (2026-06-29)


### Features

* add release-ready typed entity projections ([b2119b1](https://github.com/Arenukvern/intentcall/commit/b2119b14a1e157129ead9cf18e795bdde1ea2cd3))
* add release-ready typed entity projections ([f7b9546](https://github.com/Arenukvern/intentcall/commit/f7b9546d291f7206c3be0ea71302144de6b836eb))

## [0.4.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.3.1...intentcall_codegen-v0.4.0) (2026-06-28)


### Features

* **intentcall_platform:** add Apple inline runtime proof scaffolds ([a09f403](https://github.com/Arenukvern/intentcall/commit/a09f40326233e04e28901e2d06c7649b039a54d8))
* **intentcall_platform:** add Apple inline runtime proof scaffolds ([f9a6221](https://github.com/Arenukvern/intentcall/commit/f9a6221a0e1ff49a87dc670d6a0dbb805931522b))

## [0.3.1](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.3.0...intentcall_codegen-v0.3.1) (2026-06-27)


### Miscellaneous Chores

* **intentcall_codegen:** Synchronize intentcall package train versions

## [0.3.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.2.1...intentcall_codegen-v0.3.0) (2026-06-26)


### Features

* add Dart-first native invocation surfaces ([4d5eaae](https://github.com/Arenukvern/intentcall/commit/4d5eaae19f31e2c5acba6f40280111766710c396))


### Bug Fixes

* address release review hardening ([b908e37](https://github.com/Arenukvern/intentcall/commit/b908e378bc933ad200a2732870b6c8c608f5c470))

## [0.2.1](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.2.0...intentcall_codegen-v0.2.1) (2026-06-23)


### Miscellaneous Chores

* **intentcall_codegen:** Synchronize intentcall package train versions

## [0.2.0](https://github.com/Arenukvern/intentcall/compare/intentcall_codegen-v0.1.0...intentcall_codegen-v0.2.0) (2026-06-22)


### Features

* add adapter contract test command and enhance documentation ([dc42aa3](https://github.com/Arenukvern/intentcall/commit/dc42aa3024af2f6bda593bf37e08b3686bc0d996))


### Bug Fixes

* lints ([fc01a96](https://github.com/Arenukvern/intentcall/commit/fc01a963d1258d175314fa5838c7969386d3175d))

## 0.1.0

- First pre-release of optional IntentCall code generation.
- Includes `@AgentTool` / `@AgentParam` annotations and a build_runner
  generator for simple tool registrations.
