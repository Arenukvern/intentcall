# Changelog

## Unreleased

### Features

- Add neutral `entityTypes` manifest support and Apple App Intents entity
  projection for `AppEntity`, `IndexedEntity`, `EntityStringQuery`,
  `IndexedEntityQuery`, open intents, and `CSSearchableIndex.indexAppEntities`
  helper generation.
- Add Dart-facing and native iOS/macOS snapshot cache APIs so app-owned Dart
  snapshots can be projected into native storage for cold Apple query/indexing
  callbacks.
- Add Apple URL-scheme Info.plist sync/check support for app-owned fallback
  handoff schemes.

### Fixes

- Keep generated Apple entity Swift typecheckable by avoiding macro-backed
  property query emission in the default artifact until it has separate Xcode
  macro proof.

## [0.6.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.5.0...intentcall_platform-v0.6.0) (2026-06-29)


### Features

* add AppIntentsTesting proof tooling ([a456b30](https://github.com/Arenukvern/intentcall/commit/a456b30d6e505b0e69872fa568196efcd9136fc7))

## [0.5.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.4.0...intentcall_platform-v0.5.0) (2026-06-29)


### Features

* add release-ready typed entity projections ([b2119b1](https://github.com/Arenukvern/intentcall/commit/b2119b14a1e157129ead9cf18e795bdde1ea2cd3))
* add release-ready typed entity projections ([f7b9546](https://github.com/Arenukvern/intentcall/commit/f7b9546d291f7206c3be0ea71302144de6b836eb))

## [0.4.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.3.1...intentcall_platform-v0.4.0) (2026-06-28)


### Features

* **intentcall_platform:** add Apple inline runtime proof scaffolds ([a09f403](https://github.com/Arenukvern/intentcall/commit/a09f40326233e04e28901e2d06c7649b039a54d8))
* **intentcall_platform:** add Apple inline runtime proof scaffolds ([f9a6221](https://github.com/Arenukvern/intentcall/commit/f9a6221a0e1ff49a87dc670d6a0dbb805931522b))
* **platform:** add dispatch handoff contract ([6376056](https://github.com/Arenukvern/intentcall/commit/63760569bc2a7a508f103689d2c8932ba7fd15c5))

## [0.3.1](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.3.0...intentcall_platform-v0.3.1) (2026-06-27)


### Bug Fixes

* **intentcall_platform:** add SwiftPM support ([81d2ccf](https://github.com/Arenukvern/intentcall/commit/81d2ccf37d2726b026b2ab5b5b09e1fd3bebdace))
* **intentcall_platform:** add SwiftPM support ([7c709f0](https://github.com/Arenukvern/intentcall/commit/7c709f01f461b864b578fd4680682d6e0a18e5c9))

## [0.3.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.2.1...intentcall_platform-v0.3.0) (2026-06-26)


### Features

* add Dart-first native invocation surfaces ([4d5eaae](https://github.com/Arenukvern/intentcall/commit/4d5eaae19f31e2c5acba6f40280111766710c396))


### Bug Fixes

* address release review hardening ([b908e37](https://github.com/Arenukvern/intentcall/commit/b908e378bc933ad200a2732870b6c8c608f5c470))

## [0.2.1](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.2.0...intentcall_platform-v0.2.1) (2026-06-23)


### Miscellaneous Chores

* **intentcall_platform:** Synchronize intentcall package train versions

## [0.2.0](https://github.com/Arenukvern/intentcall/compare/intentcall_platform-v0.1.0...intentcall_platform-v0.2.0) (2026-06-22)


### Bug Fixes

* lints ([fc01a96](https://github.com/Arenukvern/intentcall/commit/fc01a963d1258d175314fa5838c7969386d3175d))

## 0.1.0

- First pre-release of platform emitters and sync helpers for IntentCall.
- Includes web manifest/WebMCP JavaScript emitters, native protocol emitters,
  platform hook initialization, and the Flutter plugin shell.
