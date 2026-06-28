import Cocoa
import FlutterMacOS

private enum IntentCallHandoffStore {
  private static let pendingKey = "intentcall.pending_invocations"

  /// Current bridge semantics are at-most-once: taking pending rows clears them
  /// before Dart execution reports success or failure.
  static func takePendingInvocations() -> [[String: Any]] {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    UserDefaults.standard.set([], forKey: pendingKey)
    return pending
  }
}

/// Plugin bridge for pending native intent dispatch into Dart.
public class IntentCallPlatformPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "intentcall_platform/invocations",
      binaryMessenger: registrar.messenger
    )
    let instance = IntentCallPlatformPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
}

extension IntentCallPlatformPlugin {
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePendingInvocations":
      result(IntentCallHandoffStore.takePendingInvocations())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
