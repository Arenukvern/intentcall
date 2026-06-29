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

private enum IntentCallEntitySnapshotStore {
  private static let prefix = "intentcall.entity_snapshots."

  static func upsert(entityType: String, snapshots: [[String: Any]]) throws -> Int {
    let type = try validateEntityType(entityType)
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var byId = Dictionary(uniqueKeysWithValues: rows(entityType: type).compactMap { row -> (String, [String: Any])? in
      guard let id = row["id"] as? String, !id.isEmpty else { return nil }
      return (id, row)
    })
    for snapshot in snapshots {
      guard let id = snapshot["id"] as? String, !id.isEmpty else { continue }
      byId[id] = snapshot
    }
    write(Array(byId.values), entityType: type)
    return snapshots.count
  }

  static func delete(entityType: String, ids: [String]) throws -> Int {
    let type = try validateEntityType(entityType)
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let remove = Set(ids)
    let current = rows(entityType: type)
    let next = current.filter { row in
      guard let id = row["id"] as? String else { return true }
      return !remove.contains(id)
    }
    write(next, entityType: type)
    return current.count - next.count
  }

  static func clear(entityType: String) throws -> Int {
    let type = try validateEntityType(entityType)
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let count = rows(entityType: type).count
    UserDefaults.standard.removeObject(forKey: key(entityType: type))
    return count
  }

  static func list(entityType: String) throws -> [[String: Any]] {
    let type = try validateEntityType(entityType)
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    return rows(entityType: type)
  }

  static func search(entityType: String, query: String, limit: Int?) throws -> [[String: Any]] {
    let type = try validateEntityType(entityType)
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let all = try list(entityType: type)
    let matched = needle.isEmpty ? all : all.filter { searchableText($0).contains(needle) }
    guard let limit, limit >= 0 else { return matched }
    return Array(matched.prefix(limit))
  }

  private static func rows(entityType: String) -> [[String: Any]] {
    let raw = UserDefaults.standard.array(forKey: key(entityType: entityType)) as? [[String: Any]] ?? []
    return raw.sorted { left, right in
      let leftId = left["id"] as? String ?? ""
      let rightId = right["id"] as? String ?? ""
      return leftId < rightId
    }
  }

  private static func write(_ rows: [[String: Any]], entityType: String) {
    UserDefaults.standard.set(rows, forKey: key(entityType: entityType))
  }

  private static func key(entityType: String) -> String {
    "\(prefix)\(entityType)"
  }

  private static func validateEntityType(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(location: 0, length: trimmed.utf16.count)
    let regex = try NSRegularExpression(pattern: "^[a-z][a-z0-9_]*_[a-z][a-z0-9_]*$")
    guard regex.firstMatch(in: trimmed, options: [], range: range) != nil else {
      throw NSError(
        domain: "IntentCallEntitySnapshotStore",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid entityType \(value)."]
      )
    }
    return trimmed
  }

  private static func searchableText(_ row: [String: Any]) -> String {
    var parts: [String] = []
    for key in ["id", "title", "subtitle", "deepLink", "url"] {
      if let value = row[key] as? String {
        parts.append(value)
      }
    }
    if let keywords = row["keywords"] as? [Any] {
      parts.append(contentsOf: keywords.map { "\($0)" })
    }
    if let properties = row["properties"] as? [String: Any] {
      parts.append(contentsOf: properties.values.map { "\($0)" })
    }
    return parts.joined(separator: " ").lowercased()
  }
}

/// Plugin bridge for pending native intent dispatch into Dart.
public class IntentCallPlatformPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let invocations = FlutterMethodChannel(
      name: "intentcall_platform/invocations",
      binaryMessenger: registrar.messenger
    )
    let entities = FlutterMethodChannel(
      name: "intentcall_platform/entities",
      binaryMessenger: registrar.messenger
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
        result(try IntentCallEntitySnapshotStore.upsert(entityType: entityType, snapshots: snapshots))
      }
    case "deleteEntitySnapshots":
      withEntityArgs(call, result) { args, entityType in
        let ids = args["ids"] as? [String] ?? []
        result(try IntentCallEntitySnapshotStore.delete(entityType: entityType, ids: ids))
      }
    case "clearEntityTypeSnapshots":
      withEntityArgs(call, result) { _, entityType in
        result(try IntentCallEntitySnapshotStore.clear(entityType: entityType))
      }
    case "listEntitySnapshots":
      withEntityArgs(call, result) { _, entityType in
        result(try IntentCallEntitySnapshotStore.list(entityType: entityType))
      }
    case "searchEntitySnapshots":
      withEntityArgs(call, result) { args, entityType in
        let query = args["query"] as? String ?? ""
        let limit = args["limit"] as? Int
        result(try IntentCallEntitySnapshotStore.search(entityType: entityType, query: query, limit: limit))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func withEntityArgs(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult,
    _ body: ([String: Any], String) throws -> Void
  ) {
    guard let args = call.arguments as? [String: Any],
          let entityType = args["entityType"] as? String else {
      result(FlutterError(code: "invalid_entity_index_request", message: "Entity index calls require entityType.", details: nil))
      return
    }
    do {
      try body(args, entityType)
    } catch {
      result(FlutterError(code: "entity_index_error", message: error.localizedDescription, details: nil))
    }
  }
}
