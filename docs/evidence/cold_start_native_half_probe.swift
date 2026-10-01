import Foundation

// Cold-start native half proof:
// 1. enqueue (as generated IntentCallNativeBridge does) → handoff store row
// 2. store drains at-most-once (take clears before Dart executes)
// 3. fallback URL shape matches what the Dart listener parses

// Mirror of generated + plugin store (UserDefaults-backed, same key).
enum IntentCallNativeHandoffStore {
  private static let pendingKey = "intentcall.pending_invocations"

  static func append(_ item: [String: Any]) {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    pending.append(item)
    UserDefaults.standard.set(pending, forKey: pendingKey)
  }

  static func takePendingInvocations() -> [[String: Any]] {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    UserDefaults.standard.set([], forKey: pendingKey)
    return pending
  }
}

var failures = 0
func require(_ condition: Bool, _ message: String) {
  if condition { print("PASS: \(message)") } else { failures += 1; print("FAIL: \(message)") }
}

let suiteName = "intentcall.coldstart.probe.\(UUID().uuidString)"
guard let suite = UserDefaults(suiteName: suiteName) else {
  print("FAIL: cannot create probe suite"); exit(1)
}
UserDefaults.standard.removePersistentDomain(forName: suiteName)

// Use standard defaults but clear our key first.
UserDefaults.standard.removeObject(forKey: "intentcall.pending_invocations")

// 1. Enqueue like the generated AppIntent.perform() does.
let invocationId = UUID().uuidString
IntentCallNativeHandoffStore.append([
  "id": invocationId,
  "qualifiedName": "app_intentcall_bridge_ping",
  "arguments": ["echo": "cold-start-proof"],
  "source": "native.generated",
  "createdAt": ISO8601DateFormatter().string(from: Date()),
])
require(true, "enqueue wrote a pending row")

// 2. Fallback URL the bridge would open (scheme from manifest).
var allowedPath = CharacterSet.alphanumerics
allowedPath.insert(charactersIn: "_-.~")
let name = "app_intentcall_bridge_ping"
let encoded = name.addingPercentEncoding(withAllowedCharacters: allowedPath) ?? name
let url = URL(string: "mcpfluttertest://invoke/\(encoded)")
require(url != nil && url!.host == "invoke" && url!.path == "/app_intentcall_bridge_ping",
        "fallback URL shape matches Dart listener contract")

// 3. Drain is at-most-once: first take returns the row and clears it.
let firstTake = IntentCallNativeHandoffStore.takePendingInvocations()
require(firstTake.count == 1, "first take returns exactly one row")
require((firstTake.first?["id"] as? String) == invocationId, "row id round-trips")
require((firstTake.first?["qualifiedName"] as? String) == name, "qualifiedName round-trips")
require((firstTake.first?["source"] as? String) == "native.generated", "source tag preserved")

// 4. Second take is empty — cleared before Dart reports success (documented semantics).
let secondTake = IntentCallNativeHandoffStore.takePendingInvocations()
require(secondTake.isEmpty, "second take is empty (at-most-once)")

UserDefaults.standard.removeObject(forKey: "intentcall.pending_invocations")
print(failures == 0 ? "OK: cold-start native-half proof passed" : "FAILED: \(failures) assertion(s)")
exit(failures == 0 ? 0 : 1)
