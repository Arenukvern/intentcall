import Cocoa
import FlutterMacOS

/// Plugin bridge for pending native intent dispatch into Dart.
public class IntentCallPlatformPlugin: NSObject, FlutterPlugin {
  private static let pendingKey = "intentcall.pending_invocations"

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
      let pending = UserDefaults.standard.array(forKey: Self.pendingKey) as? [[String: Any]] ?? []
      UserDefaults.standard.set([], forKey: Self.pendingKey)
      result(pending)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
