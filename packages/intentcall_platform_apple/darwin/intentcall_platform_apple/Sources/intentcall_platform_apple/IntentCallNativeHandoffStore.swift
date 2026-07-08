import Foundation

/// Shared native queue for App Intents / deep-link handoff into Dart.
///
/// Generated App Intents code appends via [append]; the Flutter plugin drains
/// via [takePendingInvocations] through the Pigeon bridge.
public enum IntentCallNativeHandoffStore {
  private static let pendingKey = "intentcall.pending_invocations"

  public static func append(_ item: [String: Any]) {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var pending =
      UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    pending.append(item)
    UserDefaults.standard.set(pending, forKey: pendingKey)
  }

  /// At-most-once drain semantics: clears pending rows before Dart reports success.
  public static func takePendingInvocations() -> [[String: Any]] {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let pending =
      UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    UserDefaults.standard.set([], forKey: pendingKey)
    return pending
  }
}
