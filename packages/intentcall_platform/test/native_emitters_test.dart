import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:test/test.dart';

void main() {
  final manifest = AgentManifest.fromJson(<String, Object?>{
    'version': 1,
    'platform': 'android',
    'protocolScheme': 'demoapp',
    'shortcuts': [
      <String, Object?>{
        'qualifiedName': 'app_cart_total',
        'namespace': 'app',
        'name': 'cart_total',
        'description': 'Return cart total',
        'kind': 'tool',
        'surfaces': <String, Object?>{
          'apple.appShortcuts': <String, Object?>{'include': true},
        },
        'inputSchema': <String, Object?>{
          'type': 'object',
          'required': <String>['currency'],
          'properties': <String, Object?>{
            'currency': <String, Object?>{'type': 'string'},
            'includeTax': <String, Object?>{'type': 'boolean'},
          },
        },
      },
    ],
  });

  group('AndroidShortcutsXmlEmitter', () {
    test('emits shortcut with app-owned deep link', () {
      final xml = const AndroidShortcutsXmlEmitter().emit(manifest);
      expect(xml, contains('android:shortcutId="app_cart_total"'));
      expect(xml, contains('demoapp://invoke/app_cart_total'));
      expect(xml, contains('Cart Total'));
    });

    test('matches golden xml', () {
      final xml = const AndroidShortcutsXmlEmitter().emit(manifest);
      expect(xml.trim(), _goldenAndroidShortcutsXml.trim());
    });

    test('requires an app-owned scheme', () {
      final noScheme = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'android',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_ping',
            'namespace': 'app',
            'name': 'ping',
            'description': 'Ping',
            'kind': 'tool',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      expect(
        () => const AndroidShortcutsXmlEmitter().emit(noScheme),
        throwsStateError,
      );
    });

    test('honors android.shortcuts opt-out', () {
      final xml = const AndroidShortcutsXmlEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'android',
          'protocolScheme': 'demoapp',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_hidden',
              'namespace': 'app',
              'name': 'hidden',
              'description': 'Hidden',
              'kind': 'tool',
              'surfaces': <String, Object?>{
                'android.shortcuts': <String, Object?>{'include': false},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(xml, isNot(contains('app_hidden')));
      expect(xml, contains('<shortcuts'));
    });
  });

  group('AppleSwiftAppIntentsEmitter', () {
    test('emits AppIntent and AppShortcutsProvider', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(manifest);
      expect(swift, contains('struct AppCartTotalIntent: AppIntent'));
      expect(swift, contains('@Parameter(title: "Currency")'));
      expect(swift, contains('var currency: String'));
      expect(swift, contains('var includeTax: Bool?'));
      expect(swift, contains('arguments["currency"] = currency'));
      expect(swift, contains('IntentCallShortcutsProvider'));
      expect(swift, contains('IntentCallNativeBridge'));
      expect(swift, contains('intentcall.pending_invocations'));
      expect(swift, contains('objc_sync_enter(UserDefaults.standard)'));
      expect(swift, contains('static var openAppWhenRun: Bool = true'));
      expect(
        swift,
        contains(
          'IntentCallNativeBridge.enqueue(qualifiedName: "app_cart_total", arguments: arguments, openApp: true)',
        ),
      );
      expect(swift, contains('IntentDialog("Queued invocation'));
      expect(
        swift,
        contains('private static let fallbackScheme: String? = "demoapp"'),
      );
      expect(swift, contains('demoapp'));
    });

    test('can omit URL fallback when no app scheme is declared', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_ping',
              'namespace': 'app',
              'name': 'ping',
              'description': 'Ping',
              'kind': 'tool',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(swift, contains('static var openAppWhenRun: Bool = true'));
      expect(
        swift,
        contains('private static let fallbackScheme: String? = nil'),
      );
      expect(swift, isNot(contains('demoapp://invoke/')));
    });

    test('queueOnly enqueues without requesting app open or URL dispatch', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'protocolScheme': 'demoapp',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_ping',
              'namespace': 'app',
              'name': 'ping',
              'description': 'Ping',
              'kind': 'tool',
              'dispatchMode': 'queueOnly',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(swift, contains('struct AppPingIntent: AppIntent'));
      expect(swift, contains('static var openAppWhenRun: Bool = false'));
      expect(
        swift,
        contains(
          'IntentCallNativeBridge.enqueue(qualifiedName: "app_ping", arguments: arguments, openApp: false)',
        ),
      );
      expect(
        swift,
        contains('private static let fallbackScheme: String? = nil'),
      );
      expect(swift, contains('guard openApp, let scheme = fallbackScheme'));
    });

    test('rejects inlineRuntime until Apple runtime proof exists', () {
      final inline = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'apple',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_inline',
            'namespace': 'app',
            'name': 'inline',
            'description': 'Inline',
            'kind': 'tool',
            'dispatchMode': 'inlineRuntime',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      expect(
        () => const AppleSwiftAppIntentsEmitter().emit(inline),
        throwsA(
          isA<UnsupportedError>().having(
            (final error) => error.message,
            'message',
            contains('Apple inlineRuntime dispatch is not supported yet'),
          ),
        ),
      );
    });

    test('generates wrappers broadly but curates AppShortcutsProvider', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_publish',
              'namespace': 'app',
              'name': 'publish',
              'description': 'Publish',
              'kind': 'tool',
              'surfaces': <String, Object?>{
                'apple.appShortcuts': <String, Object?>{'include': true},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
            <String, Object?>{
              'qualifiedName': 'app_private',
              'namespace': 'app',
              'name': 'private',
              'description': 'Private',
              'kind': 'tool',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(swift, contains('struct AppPublishIntent: AppIntent'));
      expect(swift, contains('struct AppPrivateIntent: AppIntent'));
      expect(
        swift,
        contains('AppShortcut(intent: AppPublishIntent(), phrases:'),
      );
      expect(swift, isNot(contains('AppShortcut(intent: AppPrivateIntent()')));
    });

    test('rejects removed includeInShortcuts field', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_publish',
              'namespace': 'app',
              'name': 'publish',
              'description': 'Publish',
              'kind': 'tool',
              'includeInShortcuts': true,
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unsafe explicit qualifiedName values', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': r'app_bad/\(name)',
              'namespace': 'app',
              'name': 'bad',
              'description': 'Bad',
              'kind': 'tool',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('matches golden swift', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(manifest);
      expect(swift.trim(), _goldenAppleSwift.trim());
    });

    test('escapes Swift reserved parameter names', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_reserved',
              'namespace': 'app',
              'name': 'reserved',
              'description': 'Reserved',
              'kind': 'tool',
              'inputSchema': <String, Object?>{
                'type': 'object',
                'required': <String>['class'],
                'properties': <String, Object?>{
                  'class': <String, Object?>{'type': 'string'},
                },
              },
            },
          ],
        }),
      );

      expect(swift, contains('var `class`: String'));
      expect(swift, contains('arguments["class"] = `class`'));
    });

    test('rejects unsupported object and array parameters', () {
      final unsupported = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'apple',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_object',
            'namespace': 'app',
            'name': 'object',
            'description': 'Object',
            'kind': 'tool',
            'inputSchema': <String, Object?>{
              'type': 'object',
              'required': <String>['payload'],
              'properties': <String, Object?>{
                'payload': <String, Object?>{'type': 'object'},
              },
            },
          },
        ],
      });

      expect(
        () => const AppleSwiftAppIntentsEmitter().emit(unsupported),
        throwsA(
          isA<UnsupportedError>().having(
            (final error) => error.message,
            'message',
            contains('app_object'),
          ),
        ),
      );
    });
  });

  group('LinuxDesktopEntryEmitter', () {
    test('registers x-scheme-handler', () {
      final desktop = const LinuxDesktopEntryEmitter().emit(manifest);
      expect(desktop, contains('x-scheme-handler/demoapp'));
      expect(desktop, contains('tool: app_cart_total'));
    });

    test('matches golden desktop entry', () {
      final desktop = const LinuxDesktopEntryEmitter().emit(manifest);
      expect(desktop.trim(), _goldenLinuxDesktop.trim());
    });

    test('honors linux.schemeHandler opt-out for tool metadata', () {
      final desktop = const LinuxDesktopEntryEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'linux',
          'protocolScheme': 'demoapp',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_hidden',
              'namespace': 'app',
              'name': 'hidden',
              'description': 'Hidden',
              'kind': 'tool',
              'surfaces': <String, Object?>{
                'linux.schemeHandler': <String, Object?>{'include': false},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(desktop, contains('x-scheme-handler/demoapp'));
      expect(desktop, isNot(contains('tool: app_hidden')));
    });
  });

  group('WindowsProtocolEmitter', () {
    test('emits registry script', () {
      final reg = const WindowsProtocolEmitter().emit(manifest);
      expect(reg, contains(r'[HKEY_CURRENT_USER\Software\Classes\demoapp]'));
      expect(reg, contains('; tool: app_cart_total'));
    });

    test('emits msix fragment', () {
      final msix = const WindowsProtocolEmitter().emitMsixFragment(manifest);
      expect(msix, contains('windows.protocol'));
      expect(msix, contains('Name="demoapp"'));
    });

    test('honors windows protocol surface opt-outs for metadata', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'windows',
        'protocolScheme': 'demoapp',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_hidden',
            'namespace': 'app',
            'name': 'hidden',
            'description': 'Hidden',
            'kind': 'tool',
            'surfaces': <String, Object?>{
              'windows.protocolActivation': <String, Object?>{'include': false},
              'windows.msixProtocol': <String, Object?>{'include': false},
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final reg = const WindowsProtocolEmitter().emit(manifest);
      final msix = const WindowsProtocolEmitter().emitMsixFragment(manifest);
      expect(reg, contains(r'[HKEY_CURRENT_USER\Software\Classes\demoapp]'));
      expect(reg, isNot(contains('tool: app_hidden')));
      expect(msix, contains('windows.protocol'));
      expect(msix, isNot(contains('app_hidden')));
    });
  });
}

const _goldenAndroidShortcutsXml = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by intentcall_platform — do not edit by hand. -->
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
  <shortcut
      android:shortcutId="app_cart_total"
      android:enabled="true"
      android:shortcutShortLabel="Cart Total"
      android:shortcutLongLabel="Return cart total">
    <intent
        android:action="android.intent.action.VIEW"
        android:data="demoapp://invoke/app_cart_total" />
  </shortcut>
</shortcuts>''';

const _goldenAppleSwift = r'''
// Generated by intentcall_platform — do not edit by hand.
import AppIntents
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(iOS 16.0, macOS 13.0, *)
struct AppCartTotalIntent: AppIntent {
  static var title: LocalizedStringResource = "Return cart total"
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Currency")
  var currency: String

  @Parameter(title: "IncludeTax")
  var includeTax: Bool?

  func perform() async throws -> some IntentResult {
    var arguments: [String: Any] = [:]
    arguments["currency"] = currency
    if let value = includeTax { arguments["includeTax"] = value }
    let invocationId = await IntentCallNativeBridge.enqueue(qualifiedName: "app_cart_total", arguments: arguments, openApp: true)
    return .result(dialog: IntentDialog("Queued invocation \(invocationId) for app dispatch."))
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct IntentCallShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: AppCartTotalIntent(), phrases: ["\(.applicationName) Cart Total"])
  }
}

enum IntentCallNativeHandoffStore {
  private static let pendingKey = "intentcall.pending_invocations"

  static func append(_ item: [String: Any]) {
    objc_sync_enter(UserDefaults.standard)
    defer { objc_sync_exit(UserDefaults.standard) }
    var pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    pending.append(item)
    UserDefaults.standard.set(pending, forKey: pendingKey)
  }
}

enum IntentCallNativeBridge {
  private static let fallbackScheme: String? = "demoapp"

  static func enqueue(qualifiedName: String, arguments: [String: Any], openApp: Bool) async -> String {
    let invocationId = UUID().uuidString
    let item: [String: Any] = [
      "id": invocationId,
      "qualifiedName": qualifiedName,
      "arguments": arguments,
      "source": "native.generated",
      "createdAt": ISO8601DateFormatter().string(from: Date())
    ]
    IntentCallNativeHandoffStore.append(item)
    var allowedPath = CharacterSet.alphanumerics
    allowedPath.insert(charactersIn: "_-.~")
    let encodedName = qualifiedName.addingPercentEncoding(withAllowedCharacters: allowedPath) ?? qualifiedName
    guard openApp, let scheme = fallbackScheme, let url = URL(string: "\(scheme)://invoke/\(encodedName)") else { return invocationId }
    #if canImport(UIKit)
    await UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
    return invocationId
  }
}''';

const _goldenLinuxDesktop = '''
# Generated by intentcall_platform — do not edit by hand.
# tool: app_cart_total
[Desktop Entry]
Type=Application
Name=Flutter App (IntentCall)
Comment=IntentCall deep-link handler
Exec=@EXEC@ %u
MimeType=x-scheme-handler/demoapp;
NoDisplay=true
Terminal=false''';
