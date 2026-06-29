# Changelog

## Unreleased

### Features

- Add portable typed entity descriptors, property descriptors, providers, index
  interfaces, and registry events so applications can describe entities and
  indexing lifecycle without Apple-specific vocabulary in core.

## [0.5.0](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.4.0...intentcall_core-v0.5.0) (2026-06-29)


### Features

* add release-ready typed entity projections ([b2119b1](https://github.com/Arenukvern/intentcall/commit/b2119b14a1e157129ead9cf18e795bdde1ea2cd3))
* add release-ready typed entity projections ([f7b9546](https://github.com/Arenukvern/intentcall/commit/f7b9546d291f7206c3be0ea71302144de6b836eb))

## [0.4.0](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.3.1...intentcall_core-v0.4.0) (2026-06-28)


### Features

* **intentcall_platform:** add Apple inline runtime proof scaffolds ([a09f403](https://github.com/Arenukvern/intentcall/commit/a09f40326233e04e28901e2d06c7649b039a54d8))
* **intentcall_platform:** add Apple inline runtime proof scaffolds ([f9a6221](https://github.com/Arenukvern/intentcall/commit/f9a6221a0e1ff49a87dc670d6a0dbb805931522b))

## [0.3.1](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.3.0...intentcall_core-v0.3.1) (2026-06-27)


### Miscellaneous Chores

* **intentcall_core:** Synchronize intentcall package train versions

## [0.3.0](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.2.1...intentcall_core-v0.3.0) (2026-06-26)


### Features

* add Dart-first native invocation surfaces ([4d5eaae](https://github.com/Arenukvern/intentcall/commit/4d5eaae19f31e2c5acba6f40280111766710c396))

## [0.2.1](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.2.0...intentcall_core-v0.2.1) (2026-06-23)


### Bug Fixes

* document registration import compatibility ([c9367da](https://github.com/Arenukvern/intentcall/commit/c9367da91c8f0364d673c1ce9f5aab2cc3031665))
* document registration import compatibility ([e42bc72](https://github.com/Arenukvern/intentcall/commit/e42bc7298e4550c42a846774180cc118a85842b0))

## [0.2.0](https://github.com/Arenukvern/intentcall/compare/intentcall_core-v0.1.0...intentcall_core-v0.2.0) (2026-06-22)


### Features

* add adapter contract test command and enhance documentation ([dc42aa3](https://github.com/Arenukvern/intentcall/commit/dc42aa3024af2f6bda593bf37e08b3686bc0d996))


### Bug Fixes

* lints ([fc01a96](https://github.com/Arenukvern/intentcall/commit/fc01a963d1258d175314fa5838c7969386d3175d))

## 0.1.0

- First pre-release of the transport-agnostic IntentCall runtime.
- Includes registry, module, authoring entry, runtime, and adapter primitives.
- Expose `MCPCallEntry` migration helpers through
  `package:intentcall_core/intentcall_core_migration.dart`.
