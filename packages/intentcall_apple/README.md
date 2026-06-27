> ⚠️ **Pre-release train** — Highly experimental. APIs may change without notice. Not for production. [Details](https://github.com/Arenukvern/intentcall/blob/main/PRE_RELEASE.md).


# intentcall_apple

Apple platform manifest and App Intents codegen for IntentCall.

Current generated App Intents collect supported primitive parameters, enqueue a
pending invocation envelope, and open or wake the Flutter app for Dart registry
execution. They return dispatch status in v1; they do not run Dart business
logic inside an App Intent extension.

## Author workflow

1. **Author tools** — hand-written `AgentCallEntry` or optional `@AgentTool` codegen (`intentcall_codegen`).
2. **Collect descriptors** — `entry.toRegistration().descriptor` or registry snapshot.
3. **Generate manifest** — `generateAppleAgentManifest(descriptors)` → `agent_manifest.json`.
4. **Platform wrapper** — generate Shortcuts / App Intents metadata that dispatches to Dart.

```dart
import 'package:intentcall_apple/intentcall_apple.dart';

final json = generateAppleAgentManifest([
  entry.toRegistration().descriptor,
]);
// write to ios/Runner/agent_manifest.json
```

Example Swift-oriented snippet derived from manifest (hand-off to Xcode codegen):

```swift
// agent_manifest.json → App Intents (illustrative)
// Intent: app_demo_ping — "Returns pong for a message"
// Parameters: message (String, required)
```

Input: `agent_manifest.json` (`platform: apple`, `intents[]`).  
Output: JSON manifest + documented Swift/Info.plist mapping for Siri/Shortcuts.

See `test/agent_manifest_generator_test.dart`.
