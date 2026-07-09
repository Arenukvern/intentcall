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
}
