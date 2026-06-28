> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_android

[![pub package](https://img.shields.io/pub/v/intentcall_android.svg?include_prereleases)](https://pub.dev/packages/intentcall_android)
[![pub points](https://img.shields.io/pub/points/intentcall_android.svg)](https://pub.dev/packages/intentcall_android/score)
[![repository](https://img.shields.io/badge/repo-intentcall-blue)](https://github.com/Arenukvern/intentcall)

Android manifest codegen for IntentCall shortcut and deep-link artifacts.

Current Android support is shortcut/deep-link dispatch into Dart. Android
AppFunctions and fuller App Actions capability generation remain roadmap work.

## Author workflow

1. **Author tools** — hand-written `AgentCallEntry` or optional `@AgentTool` codegen (`intentcall_codegen`).
2. **Collect descriptors** — `entry.toRegistration().descriptor` or registry snapshot.
3. **Generate manifest** — `generateAndroidAgentManifest(descriptors)` → `agent_manifest.json`.
4. **Platform snippet** — map manifest shortcuts to `shortcuts.xml` / deep-link routing.

```dart
import 'package:intentcall_android/intentcall_android.dart';

final json = generateAndroidAgentManifest([
  entry.toRegistration().descriptor,
]);
// write to android/app/src/main/res/values/agent_manifest.json
```

Example XML-oriented snippet derived from manifest:

```xml
<!-- agent_manifest.json → res/xml/shortcuts.xml (illustrative) -->
<!-- shortcut android:shortcutId="app_demo_ping" -->
<!--   android:shortcutShortLabel="Demo ping" /> -->
```

Input: `agent_manifest.json` (`platform: android`, `shortcuts[]`).  
Output: JSON manifest + documented shortcuts XML / deep-link mapping. Android
AppFunctions and fuller App Actions capability generation remain roadmap work.

See `test/agent_manifest_generator_test.dart`.
