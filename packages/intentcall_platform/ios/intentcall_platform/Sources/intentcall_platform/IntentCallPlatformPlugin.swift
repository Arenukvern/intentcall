import Flutter
import UIKit

/// Plugin bridge for pending native intent dispatch and entity snapshot cache.
public class IntentCallPlatformPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = IntentCallPlatformBridgeHostApiImpl()
    IntentCallInvocationsHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: bridge
    )
    IntentCallEntitiesHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: bridge
    )
  }
}

private final class IntentCallPlatformBridgeHostApiImpl: IntentCallInvocationsHostApi,
  IntentCallEntitiesHostApi
{
  func takePendingInvocations() throws -> [IntentCallInvocationEnvelopeDto] {
    IntentCallNativeHandoffStore.takePendingInvocations().compactMap(envelopeDto(from:))
  }

  func upsertEntitySnapshots(
    entityType: String,
    snapshots: [[String?: Any?]],
    keys: IntentCallEntityKeyBundle
  ) throws -> Int64 {
    Int64(
      IntentCallNativeEntitySnapshotStore.upsertSnapshots(
        entityType: entityType,
        snapshots: snapshotRows(from: snapshots),
        idKey: keys.idKey
      )
    )
  }

  func deleteEntitySnapshots(
    entityType: String,
    ids: [String],
    keys: IntentCallEntityKeyBundle
  ) throws -> Int64 {
    Int64(
      IntentCallNativeEntitySnapshotStore.deleteSnapshots(
        entityType: entityType,
        ids: ids,
        idKey: keys.idKey
      )
    )
  }

  func clearEntityTypeSnapshots(entityType: String) throws -> Int64 {
    Int64(IntentCallNativeEntitySnapshotStore.clearSnapshots(entityType: entityType))
  }

  func listEntitySnapshots(entityType: String) throws -> [[String?: Any?]] {
    snapshotRowsToPigeon(
      IntentCallNativeEntitySnapshotStore.snapshots(entityType: entityType)
    )
  }

  func searchEntitySnapshots(
    entityType: String,
    query: String,
    limit: Int64,
    keys: IntentCallEntityKeyBundle
  ) throws -> [[String?: Any?]] {
    snapshotRowsToPigeon(
      IntentCallNativeEntitySnapshotStore.search(
        entityType: entityType,
        query: query,
        titleKey: keys.titleKey,
        subtitleKey: keys.subtitleKey,
        keywordsKey: keys.keywordsKey,
        limit: Int(limit)
      )
    )
  }

  func takePendingEntityOpens() throws -> [IntentCallEntityOpenEnvelopeDto] {
    IntentCallNativeEntitySnapshotStore.takePendingEntityOpens().compactMap(entityOpenDto(from:))
  }

  private func envelopeDto(from row: [String: Any]) -> IntentCallInvocationEnvelopeDto? {
    guard
      let id = IntentCallNativeEntitySnapshotStore.string(row["id"]),
      let qualifiedName = IntentCallNativeEntitySnapshotStore.string(row["qualifiedName"]),
      let source = IntentCallNativeEntitySnapshotStore.string(row["source"]),
      let createdAt = IntentCallNativeEntitySnapshotStore.string(row["createdAt"])
    else {
      return nil
    }
    let arguments = pigeonMap(from: row["arguments"] as? [String: Any])
    return IntentCallInvocationEnvelopeDto(
      id: id,
      qualifiedName: qualifiedName,
      arguments: arguments,
      source: source,
      createdAt: createdAt
    )
  }

  private func entityOpenDto(from row: [String: Any]) -> IntentCallEntityOpenEnvelopeDto? {
    guard
      let id = IntentCallNativeEntitySnapshotStore.string(row["id"]),
      let entityType = IntentCallNativeEntitySnapshotStore.string(row["entityType"]),
      let entityId = IntentCallNativeEntitySnapshotStore.string(row["entityId"]),
      let source = IntentCallNativeEntitySnapshotStore.string(row["source"]),
      let createdAt = IntentCallNativeEntitySnapshotStore.string(row["createdAt"])
    else {
      return nil
    }
    return IntentCallEntityOpenEnvelopeDto(
      id: id,
      entityType: entityType,
      entityId: entityId,
      source: source,
      createdAt: createdAt
    )
  }

  private func pigeonMap(from row: [String: Any]?) -> [String?: Any?]? {
    guard let row else { return nil }
    var normalized = [String?: Any?]()
    for (key, value) in row {
      normalized[key] = value
    }
    return normalized
  }

  private func snapshotRows(from rows: [[String?: Any?]]) -> [[String: Any]] {
    rows.map { row in
      var normalized = [String: Any]()
      for (key, value) in row {
        guard let key else { continue }
        normalized[key] = value as Any
      }
      return normalized
    }
  }

  private func snapshotRowsToPigeon(_ rows: [[String: Any]]) -> [[String?: Any?]] {
    rows.map { row in
      var normalized = [String?: Any?]()
      for (key, value) in row {
        normalized[key] = value
      }
      return normalized
    }
  }
}
