import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
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
      expect(
        swift,
        contains(
          'static var supportedModes: IntentModes { .foreground(.immediate) }',
        ),
      );
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

    test('emits AppEntity snapshots, query, open intent, and index helper', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'protocolScheme': 'demoapp',
          'entityTypes': [
            <String, Object?>{
              'qualifiedName': 'app_project',
              'namespace': 'app',
              'name': 'project',
              'displayName': 'Project',
              'description': 'Open project',
              'titleKey': 'name',
              'subtitleKey': 'summary',
              'keywordsKey': 'tags',
              'defaultQueryLimit': 7,
            },
          ],
          'tools': const <Object?>[],
        }),
      );

      expect(swift, contains('import CoreSpotlight'));
      expect(
        swift,
        contains('struct AppProjectEntity: AppEntity, IndexedEntity'),
      );
      expect(
        swift,
        contains('static var defaultQuery = AppProjectEntityQuery()'),
      );
      expect(
        swift,
        contains(
          'struct AppProjectEntityQuery: EntityStringQuery, IndexedEntityQuery',
        ),
      );
      expect(swift, contains('let title: String'));
      expect(swift, contains('let subtitle: String'));
      expect(swift, contains('let keywords: [String]'));
      expect(swift, isNot(contains('ComputedProperty')));
      expect(swift, isNot(contains('EntityPropertyQuery')));
      expect(swift, contains('entities(for identifiers: [String])'));
      expect(swift, contains('func entities(matching string: String)'));
      expect(swift, contains('@available(iOS 27.0, macOS 27.0, *)'));
      expect(swift, contains('func reindexAllEntities('));
      expect(swift, contains('struct AppOpenProjectEntityIntent: OpenIntent'));
      expect(
        swift,
        contains(
          'IntentCallNativeEntitySnapshotStore.recordOpen(entityType: "app_project", id: target.id)',
        ),
      );
      expect(swift, contains('enum IntentCallNativeEntitySnapshotStore'));
      expect(
        swift,
        contains(
          'private static let snapshotsKeyPrefix = "intentcall.entity_snapshots."',
        ),
      );
      expect(swift, contains('static func indexAppEntities() async throws'));
      expect(swift, contains('CSSearchableIndex.default().indexAppEntities'));
      expect(swift, contains('static func deleteAppEntities('));
      expect(
        swift,
        contains(
          'IntentCallNativeEntitySnapshotStore.search(entityType: "app_project", query: string, titleKey: "name", subtitleKey: "summary", keywordsKey: "tags", limit: 7)',
        ),
      );
      expect(
        swift,
        contains('private static let fallbackScheme: String? = "demoapp"'),
      );
      expect(swift, isNot(contains('FlutterEngine')));
      expect(swift, isNot(contains('FlutterMethodChannel')));
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

      expect(
        swift,
        contains(
          'static var supportedModes: IntentModes { .foreground(.immediate) }',
        ),
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
      expect(
        swift,
        contains('static var supportedModes: IntentModes { .background }'),
      );
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

    test('nativeInline emits handler invocation without app wake', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'protocolScheme': 'demoapp',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'Inline',
              'kind': 'tool',
              'dispatchMode': 'inlineRuntime',
              'inlineRuntime': <String, Object?>{
                'kind': 'nativeInline',
                'platforms': <String, Object?>{
                  'apple': <String, Object?>{'target': 'mainApp'},
                },
              },
              'inputSchema': <String, Object?>{
                'type': 'object',
                'required': <String>['message'],
                'properties': <String, Object?>{
                  'message': <String, Object?>{'type': 'string'},
                },
              },
            },
          ],
        }),
      );

      expect(swift, contains('struct AppInlineIntent: AppIntent'));
      expect(
        swift,
        contains('static var supportedModes: IntentModes { .background }'),
      );
      expect(swift, isNot(contains('openAppWhenRun')));
      expect(
        swift,
        contains(
          'IntentCallAppleInlineRuntime.perform(qualifiedName: "app_inline", arguments: arguments)',
        ),
      );
      expect(swift, contains('IntentCallInlineRuntimeError'));
      expect(swift, contains('No native inline handler registered'));
      expect(
        swift,
        contains(
          'return .result(dialog: IntentDialog(stringLiteral: inlineResult.dialog))',
        ),
      );
      expect(
        swift,
        contains('private static let fallbackScheme: String? = nil'),
      );
      expect(
        swift,
        isNot(contains('app_inline", arguments: arguments, openApp')),
      );
    });

    test('nativeInline emits typed App Intents return value', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        AgentManifest.fromJson(<String, Object?>{
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
              'inlineRuntime': <String, Object?>{
                'kind': 'nativeInline',
                'result': <String, Object?>{'type': 'string'},
                'platforms': <String, Object?>{
                  'apple': <String, Object?>{'target': 'mainApp'},
                },
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      expect(
        swift,
        contains(
          'static var allowedExecutionTargets: IntentExecutionTargets { .main }',
        ),
      );
      expect(
        swift,
        contains(
          'func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog',
        ),
      );
      expect(
        swift,
        contains(
          'IntentCallAppleInlineRuntime.typedValue(inlineResult, as: String.self, qualifiedName: "app_inline")',
        ),
      );
      expect(
        swift,
        contains(
          'return .result(value: value, dialog: IntentDialog(stringLiteral: inlineResult.dialog))',
        ),
      );
      expect(swift, contains('case invalidTypedResult(String, String)'));
      expect(
        swift,
        contains(
          'init(dialog: String = "Completed inline runtime invocation.", value: Any? = nil)',
        ),
      );
    });

    test('rejects inlineRuntime without inlineRuntime metadata', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
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
        }),
        throwsFormatException,
      );
    });

    test('rejects Apple dartExtensionInline until runtime proof exists', () {
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
            'inlineRuntime': <String, Object?>{
              'kind': 'dartExtensionInline',
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'appIntentsExtension'},
              },
            },
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
            contains(
              'AppleDartExtensionInlineEmitter(enableExperimental: true)',
            ),
          ),
        ),
      );
    });

    test('rejects Apple nativeInline app extension target for now', () {
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
            'inlineRuntime': <String, Object?>{
              'kind': 'nativeInline',
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'appIntentsExtension'},
              },
            },
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
            contains('target "mainApp" only'),
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

  group('AppleDartExtensionInlineEmitter', () {
    test('requires explicit experimental gate', () {
      final manifest = _dartExtensionInlineManifest();

      expect(
        () => const AppleDartExtensionInlineEmitter().emitSwiftExtension(
          manifest,
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (final error) => error.message,
            'message',
            contains('enableExperimental: true'),
          ),
        ),
      );
    });

    test('emits extension Swift scaffold for Dart runtime boot', () {
      final swift = const AppleDartExtensionInlineEmitter(
        enableExperimental: true,
      ).emitSwiftExtension(_dartExtensionInlineManifest());

      expect(swift, contains('@main'));
      expect(
        swift,
        contains(
          'struct IntentCallDartExtensionInlineExtension: AppIntentsExtension',
        ),
      );
      expect(swift, contains('import FlutterMacOS'));
      expect(swift, contains('import Flutter'));
      expect(swift, contains('struct AppInlineIntent: AppIntent'));
      expect(
        swift,
        contains('static var supportedModes: IntentModes { .background }'),
      );
      expect(
        swift,
        contains(
          'static var allowedExecutionTargets: IntentExecutionTargets { .appIntentsExtension }',
        ),
      );
      expect(
        swift,
        contains(
          'IntentCallDartExtensionInlineRuntime.perform(qualifiedName: "app_inline", arguments: arguments)',
        ),
      );
      expect(swift, contains('FlutterEngine(name:'));
      expect(swift, contains('next.run(withEntrypoint: dartEntrypoint)'));
      expect(
        swift,
        contains(
          'FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)',
        ),
      );
      expect(swift, contains('"source": "apple.dart_extension_inline"'));
      expect(swift, contains('registerAllowedPlugins(with: next)'));
      expect(swift, contains('audited extension-safe plugins'));
    });

    test('emits typed Dart extension inline App Intents return value', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
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
            'inlineRuntime': <String, Object?>{
              'kind': 'dartExtensionInline',
              'result': <String, Object?>{
                'type': 'integer',
                'dataKey': 'count',
              },
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'appIntentsExtension'},
              },
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      final swift = const AppleDartExtensionInlineEmitter(
        enableExperimental: true,
      ).emitSwiftExtension(manifest);

      expect(
        swift,
        contains(
          'func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog',
        ),
      );
      expect(swift, contains('let data: [String: Any]'));
      expect(
        swift,
        contains('let data = map["data"] as? [String: Any] ?? [:]'),
      );
      expect(
        swift,
        contains(
          'typedValue(result, dataKey: "count", as: Int.self, qualifiedName: "app_inline")',
        ),
      );
      expect(
        swift,
        contains(
          'return .result(value: value, dialog: IntentDialog(stringLiteral: result.dialog))',
        ),
      );
      expect(
        swift,
        contains('case invalidTypedResult(String, String, String)'),
      );
    });

    test('emits Dart entrypoint template for registry invocation', () {
      final dart = const AppleDartExtensionInlineEmitter(
        enableExperimental: true,
      ).emitDartEntrypointTemplate();

      expect(dart, contains("@pragma('vm:entry-point')"));
      expect(dart, contains('void intentCallDartExtensionInlineMain()'));
      expect(
        dart,
        contains("MethodChannel('dev.intentcall/dart_extension_inline')"),
      );
      expect(
        dart,
        contains('IntentCallDartExtensionInlineRuntime.bindRegistry'),
      );
      expect(dart, contains('buildIntentCallDartExtensionRegistry()'));
      expect(dart, contains('IntentCallAuthorizationPolicy.denyAll'));
    });

    test('rejects dartExtensionInline without extension target', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
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
            'inlineRuntime': <String, Object?>{
              'kind': 'dartExtensionInline',
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'mainApp'},
              },
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      expect(
        () => const AppleDartExtensionInlineEmitter(
          enableExperimental: true,
        ).emitSwiftExtension(manifest),
        throwsA(
          isA<UnsupportedError>().having(
            (final error) => error.message,
            'message',
            contains('requires target "appIntentsExtension"'),
          ),
        ),
      );
    });
  });

  group('AppleAppIntentsTestingEmitter', () {
    test('emits AppIntentsTesting live invocation scaffold', () {
      final swift = const AppleAppIntentsTestingEmitter(
        bundleIdentifier: 'com.example.intentcall',
        sampleArguments: <String, Map<String, Object?>>{
          'app_cart_total': <String, Object?>{
            'currency': 'USD',
            'includeTax': true,
          },
        },
      ).emitUiTests(manifest);

      expect(swift, contains('#if canImport(AppIntentsTesting)'));
      expect(swift, contains('import AppIntentsTesting'));
      expect(swift, contains('import XCTest'));
      expect(
        swift,
        contains(
          'final class IntentCallAppIntentsLiveInvocationTests: XCTestCase',
        ),
      );
      expect(swift, contains('await XCUIApplication().launch()'));
      expect(
        swift,
        contains(
          'IntentDefinitions(bundleIdentifier: "com.example.intentcall")',
        ),
      );
      expect(
        swift,
        contains(
          'let intent = definitions.intents["AppCartTotalIntent"].makeIntent(currency: "USD", includeTax: true)',
        ),
      );
      expect(swift, contains('let result = try await intent.run()'));
    });

    test('emits typed result extraction for live invocation scaffold', () {
      final swift =
          const AppleAppIntentsTestingEmitter(
            bundleIdentifier: 'com.example.intentcall',
          ).emitUiTests(
            AgentManifest.fromJson(<String, Object?>{
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
                  'inlineRuntime': <String, Object?>{
                    'kind': 'nativeInline',
                    'result': <String, Object?>{'type': 'number'},
                    'platforms': <String, Object?>{
                      'apple': <String, Object?>{'target': 'mainApp'},
                    },
                  },
                  'inputSchema': <String, Object?>{'type': 'object'},
                },
              ],
            }),
          );

      expect(swift, contains('let result = try await intent.run()'));
      expect(swift, contains('let value: Double = try result.value'));
      expect(swift, contains('_ = value'));
    });

    test('emits entity query and Spotlight scaffolds from fixtures', () {
      final swift =
          const AppleAppIntentsTestingEmitter(
            bundleIdentifier: 'com.example.intentcall',
            entityFixtures: <String, AppleAppIntentsTestingEntityFixture>{
              'app_project': AppleAppIntentsTestingEntityFixture(
                identifier: 'project-1',
                search: 'Apollo',
                expectedTitle: 'Apollo Roadmap',
              ),
            },
          ).emitUiTests(
            AgentManifest.fromJson(<String, Object?>{
              'version': 1,
              'platform': 'apple',
              'entityTypes': [
                <String, Object?>{
                  'qualifiedName': 'app_project',
                  'namespace': 'app',
                  'name': 'project',
                  'displayName': 'Project',
                  'description': 'Open project',
                },
                <String, Object?>{
                  'qualifiedName': 'app_customer',
                  'namespace': 'app',
                  'name': 'customer',
                  'displayName': 'Customer',
                  'description': 'Open customer',
                },
              ],
              'tools': const <Object?>[],
            }),
          );

      expect(swift, contains('@available(iOS 27.0, macOS 27.0, *)'));
      expect(
        swift,
        contains(
          'let entityDefinition = try XCTUnwrap(definitions.entities["AppProjectEntity"])',
        ),
      );
      expect(
        swift,
        contains(
          'let byIdentifier = try await entityDefinition.entities(identifiers: ["project-1"])',
        ),
      );
      expect(
        swift,
        contains(
          'let bySearch = try await entityDefinition.entities(matching: "Apollo")',
        ),
      );
      expect(
        swift,
        contains(
          r'XCTAssertTrue(bySearch.contains { String(describing: $0.displayRepresentation.title).contains("Apollo Roadmap") })',
        ),
      );
      expect(
        swift,
        contains(
          'let suggested = try await entityDefinition.suggestedEntities()',
        ),
      );
      expect(
        swift,
        contains('let all = try await entityDefinition.allEntities()'),
      );
      expect(swift, contains('#if os(iOS) || os(macOS)'));
      expect(
        swift,
        contains(
          'let spotlight = try await entityDefinition.spotlightQuery("Apollo")',
        ),
      );
      expect(swift, isNot(contains('AppCustomerEntity')));
    });

    test('requires live sample values for required parameters', () {
      expect(
        () => const AppleAppIntentsTestingEmitter(
          bundleIdentifier: 'com.example.intentcall',
        ).emitUiTests(manifest),
        throwsA(
          isA<UnsupportedError>().having(
            (final error) => error.message,
            'message',
            contains('Missing sample argument "currency"'),
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

AgentManifest _dartExtensionInlineManifest() =>
    AgentManifest.fromJson(<String, Object?>{
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
          'inlineRuntime': <String, Object?>{
            'kind': 'dartExtensionInline',
            'platforms': <String, Object?>{
              'apple': <String, Object?>{'target': 'appIntentsExtension'},
            },
          },
          'inputSchema': <String, Object?>{
            'type': 'object',
            'required': <String>['message'],
            'properties': <String, Object?>{
              'message': <String, Object?>{'type': 'string'},
              'count': <String, Object?>{'type': 'integer'},
            },
          },
        },
      ],
    });

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
  @available(iOS 26.0, macOS 26.0, *)
  static var supportedModes: IntentModes { .foreground(.immediate) }
  static var openAppWhenRun: Bool = true
  @available(iOS 27.0, macOS 27.0, *)
  static var allowedExecutionTargets: IntentExecutionTargets { .default }

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

struct IntentCallInlineRuntimeResult {
  let dialog: String
  let value: Any?

  init(dialog: String = "Completed inline runtime invocation.", value: Any? = nil) {
    self.dialog = dialog
    self.value = value
  }
}

enum IntentCallInlineRuntimeError: Error, CustomStringConvertible {
  case missingHandler(String)
  case handlerFailed(String)
  case invalidTypedResult(String, String)

  var description: String {
    switch self {
    case .missingHandler(let qualifiedName):
      return "No native inline handler registered for \(qualifiedName)."
    case .handlerFailed(let message):
      return "Inline runtime failed: \(message)"
    case .invalidTypedResult(let qualifiedName, let typeName):
      return "Inline runtime for \(qualifiedName) did not return \(typeName)."
    }
  }
}

typealias IntentCallAppleInlineRuntimeHandler = @Sendable ([String: Any]) async throws -> IntentCallInlineRuntimeResult

enum IntentCallAppleInlineRuntime {
  private static let lock = NSObject()
  private nonisolated(unsafe) static var handlers: [String: IntentCallAppleInlineRuntimeHandler] = [:]

  static func register(qualifiedName: String, handler: @escaping IntentCallAppleInlineRuntimeHandler) {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    handlers[qualifiedName] = handler
  }

  static func perform(qualifiedName: String, arguments: [String: Any]) async throws -> IntentCallInlineRuntimeResult {
    objc_sync_enter(lock)
    let handler = handlers[qualifiedName]
    objc_sync_exit(lock)
    guard let handler else {
      throw IntentCallInlineRuntimeError.missingHandler(qualifiedName)
    }
    do {
      return try await handler(arguments)
    } catch let error as IntentCallInlineRuntimeError {
      throw error
    } catch {
      throw IntentCallInlineRuntimeError.handlerFailed(error.localizedDescription)
    }
  }

  static func typedValue<T>(_ result: IntentCallInlineRuntimeResult, as type: T.Type, qualifiedName: String) throws -> T {
    guard let raw = result.value else {
      throw IntentCallInlineRuntimeError.invalidTypedResult(qualifiedName, String(describing: T.self))
    }
    if let value = raw as? T {
      return value
    }
    if T.self == Int.self, let value = raw as? NSNumber {
      return value.intValue as! T
    }
    if T.self == Double.self, let value = raw as? NSNumber {
      return value.doubleValue as! T
    }
    if T.self == Bool.self, let value = raw as? NSNumber {
      return value.boolValue as! T
    }
    throw IntentCallInlineRuntimeError.invalidTypedResult(qualifiedName, String(describing: T.self))
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
