import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared native cache for Dart-projected entity snapshots.
///
/// Generated App Intents entity/query code and the Flutter plugin bridge both
/// read and write through this store.
public enum IntentCallNativeEntitySnapshotStore {
  public static let snapshotsDidChangeNotification = Notification.Name(
    "intentcall.entitySnapshotsDidChange"
  )

  public static var fallbackScheme: String?

  private static let snapshotsKeyPrefix = "intentcall.entity_snapshots."
  private static let pendingOpenKey = "intentcall.pending_entity_opens"

  @discardableResult
  public static func upsertSnapshots(
    entityType: String,
    snapshots: [[String: Any]],
    idKey: String = "id"
  ) -> Int {
    guard let type = validatedEntityType(entityType) else { return 0 }
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var existing =
      UserDefaults.standard.array(forKey: snapshotsKey(entityType: type))
      as? [[String: Any]] ?? []
    var byId = Dictionary(
      uniqueKeysWithValues: existing.compactMap { snapshot -> (String, [String: Any])? in
        guard let id = string(snapshot[idKey]) else { return nil }
        return (id, snapshot)
      }
    )
    for snapshot in snapshots {
      guard let id = string(snapshot[idKey]) else { continue }
      byId[id] = snapshot
    }
    existing = Array(byId.values)
    UserDefaults.standard.set(existing, forKey: snapshotsKey(entityType: type))
    NotificationCenter.default.post(name: snapshotsDidChangeNotification, object: nil)
    return snapshots.count
  }

  @discardableResult
  public static func deleteSnapshots(
    entityType: String,
    ids: [String],
    idKey: String = "id"
  ) -> Int {
    guard let type = validatedEntityType(entityType) else { return 0 }
    let deleted = Set(ids)
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    let existing =
      UserDefaults.standard.array(forKey: snapshotsKey(entityType: type))
      as? [[String: Any]] ?? []
    let kept = existing.filter { snapshot in
      guard let id = string(snapshot[idKey]) else { return true }
      return !deleted.contains(id)
    }
    UserDefaults.standard.set(kept, forKey: snapshotsKey(entityType: type))
    let removed = existing.count - kept.count
    if removed > 0 {
      NotificationCenter.default.post(name: snapshotsDidChangeNotification, object: nil)
    }
    return removed
  }

  @discardableResult
  public static func clearSnapshots(entityType: String) -> Int {
    guard let type = validatedEntityType(entityType) else { return 0 }
    let existing = snapshots(entityType: type).count
    UserDefaults.standard.removeObject(forKey: snapshotsKey(entityType: type))
    if existing > 0 {
      NotificationCenter.default.post(name: snapshotsDidChangeNotification, object: nil)
    }
    return existing
  }

  public static func snapshots(entityType: String) -> [[String: Any]] {
    guard let type = validatedEntityType(entityType) else { return [] }
    return UserDefaults.standard.array(forKey: snapshotsKey(entityType: type))
      as? [[String: Any]] ?? []
  }

  public static func entities(
    entityType: String,
    identifiers: [String],
    idKey: String,
    limit: Int?
  ) -> [[String: Any]] {
    let wanted = Set(identifiers)
    let matches = snapshots(entityType: entityType).filter { snapshot in
      guard let id = string(snapshot[idKey]) else { return false }
      return wanted.contains(id)
    }
    return applyingLimit(matches, limit: limit)
  }

  public static func suggested(entityType: String, limit: Int) -> [[String: Any]] {
    applyingLimit(snapshots(entityType: entityType), limit: limit)
  }

  public static func search(
    entityType: String,
    query: String,
    titleKey: String,
    subtitleKey: String,
    keywordsKey: String,
    limit: Int
  ) -> [[String: Any]] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let all = snapshots(entityType: entityType)
    guard !needle.isEmpty else {
      return suggested(entityType: entityType, limit: limit)
    }
    let matches = all.filter { snapshot in
      let fields =
        [string(snapshot[titleKey]), string(snapshot[subtitleKey])].compactMap { $0 }
        + strings(snapshot[keywordsKey])
      return fields.contains { $0.lowercased().contains(needle) }
    }
    return applyingLimit(matches, limit: limit)
  }

  public static func recordOpen(entityType: String, id: String) async -> String {
    let type = validatedEntityType(entityType) ?? entityType
    let openId = UUID().uuidString
    let item: [String: Any] = [
      "id": openId,
      "entityType": type,
      "entityId": id,
      "source": "native.entity.generated",
      "createdAt": ISO8601DateFormatter().string(from: Date()),
    ]
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var pending =
      UserDefaults.standard.array(forKey: pendingOpenKey) as? [[String: Any]] ?? []
    pending.append(item)
    UserDefaults.standard.set(pending, forKey: pendingOpenKey)
    guard let scheme = fallbackScheme else { return openId }
    let encodedEntityType = encodedPathComponent(type)
    let encodedId = encodedPathComponent(id)
    guard let url = URL(string: "\(scheme)://entity/\(encodedEntityType)/\(encodedId)") else {
      return openId
    }
    #if canImport(UIKit)
    await UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
    return openId
  }

  public static func string(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? CustomStringConvertible { return value.description }
    return nil
  }

  public static func strings(_ value: Any?) -> [String] {
    if let values = value as? [String] { return values }
    if let values = value as? [Any] { return values.compactMap { string($0) } }
    if let value = string(value) { return [value] }
    return []
  }

  private static func snapshotsKey(entityType: String) -> String {
    snapshotsKeyPrefix + entityType
  }

  private static func applyingLimit(_ rows: [[String: Any]], limit: Int?) -> [[String: Any]] {
    guard let limit else { return rows }
    return Array(rows.prefix(max(0, limit)))
  }

  private static func encodedPathComponent(_ value: String) -> String {
    var allowedPath = CharacterSet.alphanumerics
    allowedPath.insert(charactersIn: "_-.~")
    return value.addingPercentEncoding(withAllowedCharacters: allowedPath) ?? value
  }

  private static func validatedEntityType(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(location: 0, length: trimmed.utf16.count)
    guard
      let regex = try? NSRegularExpression(pattern: "^[a-z][a-z0-9_]*_[a-z][a-z0-9_]*$"),
      regex.firstMatch(in: trimmed, options: [], range: range) != nil
    else {
      return nil
    }
    return trimmed
  }
}
