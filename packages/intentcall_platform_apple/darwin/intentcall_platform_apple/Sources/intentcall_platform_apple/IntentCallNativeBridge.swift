import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Native handoff facade for generated App Intents in the consuming app Runner target.
///
/// Generated `IntentCallGenerated.swift` imports `intentcall_platform_apple` and
/// calls [enqueue] instead of duplicating queue + deep-link logic per app.
public enum IntentCallNativeBridge {
  public static func enqueue(
    qualifiedName: String,
    arguments: [String: Any],
    openApp: Bool,
    fallbackProtocolScheme: String? = nil
  ) async -> String {
    let invocationId = UUID().uuidString
    let item: [String: Any] = [
      "id": invocationId,
      "qualifiedName": qualifiedName,
      "arguments": arguments,
      "source": "native.generated",
      "createdAt": ISO8601DateFormatter().string(from: Date()),
    ]
    IntentCallNativeHandoffStore.append(item)
    var allowedPath = CharacterSet.alphanumerics
    allowedPath.insert(charactersIn: "_-.~")
    let encodedName =
      qualifiedName.addingPercentEncoding(withAllowedCharacters: allowedPath)
      ?? qualifiedName
    guard openApp,
      let scheme = fallbackProtocolScheme,
      let url = URL(string: "\(scheme)://invoke/\(encodedName)")
    else { return invocationId }
    #if canImport(UIKit)
    await UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
    return invocationId
  }

  /// Waits for the running Flutter host to execute [qualifiedName].
  ///
  /// Does not write the at-most-once handoff queue. A missing host returns
  /// `runtime_unavailable` after [timeoutSeconds]. The wake URL is
  /// `scheme://wake`, which the deep-link listener ignores.
  public static func invokeAwaiting(
    qualifiedName: String,
    arguments: [String: Any],
    fallbackProtocolScheme: String? = nil,
    timeoutSeconds: TimeInterval = 10
  ) async -> IntentCallAwaitOutcome {
    if let scheme = fallbackProtocolScheme,
      let url = URL(string: "\(scheme)://wake")
    {
      #if canImport(UIKit)
      await UIApplication.shared.open(url)
      #elseif canImport(AppKit)
      NSWorkspace.shared.open(url)
      #endif
    }
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while awaitingApi == nil && Date() < deadline {
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    guard let api = awaitingApi else {
      return IntentCallAwaitOutcome.failure(
        code: "runtime_unavailable",
        message: "Flutter host is not answering."
      )
    }
    let envelope = IntentCallInvocationEnvelopeDto(
      id: UUID().uuidString,
      qualifiedName: qualifiedName,
      arguments: pigeonArguments(arguments),
      source: "apple.await_app",
      createdAt: ISO8601DateFormatter().string(from: Date())
    )
    return await withCheckedContinuation { continuation in
      api.invoke(envelope: envelope) { result in
        switch result {
        case .success(let dto):
          continuation.resume(
            returning: IntentCallAwaitOutcome(
              ok: dto.ok,
              code: dto.code ?? "",
              dialog: dto.dialog
            )
          )
        case .failure(let error):
          continuation.resume(
            returning: IntentCallAwaitOutcome.failure(
              code: error.code,
              message: error.message ?? "Awaiting invocation failed."
            )
          )
        }
      }
    }
  }

  /// Internal: the Pigeon-generated `IntentCallAwaitingFlutterApiProtocol`
  /// is internal, so a public signature here would not compile ("parameter
  /// uses an internal type"). Only `IntentCallPlatformPlugin` calls this,
  /// same module.
  static func registerAwaitingApi(_ api: IntentCallAwaitingFlutterApi?) {
    awaitingApi = api
  }

  private static var awaitingApi: IntentCallAwaitingFlutterApi?

  private static func pigeonArguments(_ arguments: [String: Any]) -> [String?: Any?] {
    var normalized = [String?: Any?]()
    for (key, value) in arguments {
      normalized[key] = value
    }
    return normalized
  }
}

public struct IntentCallAwaitOutcome: Sendable {
  public let ok: Bool
  public let code: String
  public let dialog: String

  public static func failure(code: String, message: String) -> IntentCallAwaitOutcome {
    let payload: [String: Any] = [
      "ok": false,
      "code": code,
      "message": message,
    ]
    let dialog: String
    if let data = try? JSONSerialization.data(withJSONObject: payload),
      let text = String(data: data, encoding: .utf8)
    {
      dialog = text
    } else {
      dialog = "runtime failure \(code)"
    }
    return IntentCallAwaitOutcome(ok: false, code: code, dialog: dialog)
  }
}
