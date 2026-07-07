import Flutter
import UIKit

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
    let invocations = FlutterMethodChannel(
      name: "intentcall_platform/invocations",
      binaryMessenger: registrar.messenger()
    )
    let entities = FlutterMethodChannel(
      name: "intentcall_platform/entities",
      binaryMessenger: registrar.messenger()
    )
    let instance = IntentCallPlatformPlugin()
    registrar.addMethodCallDelegate(instance, channel: invocations)
    registrar.addMethodCallDelegate(instance, channel: entities)
  }
}

extension IntentCallPlatformPlugin {
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePendingInvocations":
      result(IntentCallHandoffStore.takePendingInvocations())
    case "upsertEntitySnapshots":
      withEntityArgs(call, result) { args, entityType in
        let snapshots = args["snapshots"] as? [[String: Any]] ?? []
        let idKey = args["idKey"] as? String ?? "id"
        result(
          IntentCallNativeEntitySnapshotStore.upsertSnapshots(
            entityType: entityType,
            snapshots: snapshots,
            idKey: idKey
          )
        )
      }
    case "deleteEntitySnapshots":
      withEntityArgs(call, result) { args, entityType in
        let ids = args["ids"] as? [String] ?? []
        let idKey = args["idKey"] as? String ?? "id"
        result(
          IntentCallNativeEntitySnapshotStore.deleteSnapshots(
            entityType: entityType,
            ids: ids,
            idKey: idKey
          )
        )
      }
    case "clearEntityTypeSnapshots":
      withEntityArgs(call, result) { _, entityType in
        result(IntentCallNativeEntitySnapshotStore.clearSnapshots(entityType: entityType))
      }
    case "listEntitySnapshots":
      withEntityArgs(call, result) { _, entityType in
        result(IntentCallNativeEntitySnapshotStore.snapshots(entityType: entityType))
      }
    case "searchEntitySnapshots":
      withEntityArgs(call, result) { args, entityType in
        let query = args["query"] as? String ?? ""
        let limit = args["limit"] as? Int ?? 20
        let titleKey = args["titleKey"] as? String ?? "title"
        let subtitleKey = args["subtitleKey"] as? String ?? "subtitle"
        let keywordsKey = args["keywordsKey"] as? String ?? "keywords"
        result(
          IntentCallNativeEntitySnapshotStore.search(
            entityType: entityType,
            query: query,
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            keywordsKey: keywordsKey,
            limit: limit
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func withEntityArgs(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult,
    _ body: ([String: Any], String) -> Void
  ) {
    guard let args = call.arguments as? [String: Any],
          let entityType = args["entityType"] as? String else {
      result(FlutterError(code: "invalid_entity_index_request", message: "Entity index calls require entityType.", details: nil))
      return
    }
    body(args, entityType)
  }
}
