> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_android

Android manifest codegen for intentcall (App Actions / dynamic shortcuts export).

## Author workflow

1. **Author tools** — hand-written `AgentCallEntry` or optional `@AgentTool` codegen (`intentcall_codegen`).
2. **Collect descriptors** — `entry.toRegistration().descriptor` or registry snapshot.
3. **Generate manifest** — `generateAndroidAgentManifest(descriptors)` → `agent_manifest.json`.
4. **Platform snippet** — map manifest shortcuts to `shortcuts.xml` / App Actions.

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
Output: JSON manifest + documented XML mapping for App Actions.

See `test/agent_manifest_generator_test.dart`.