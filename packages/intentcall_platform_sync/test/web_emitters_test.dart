import 'dart:convert';
import 'dart:io';

import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

void main() {
  group('WebManifestEmitter', () {
    test('patches shortcuts and protocol_handlers from agent manifest', () {
      const baseManifest = '''
{
    "name": "demo",
    "short_name": "demo",
    "start_url": "."
}
''';
      final agentManifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_cart_total',
            'namespace': 'app',
            'name': 'cart_total',
            'description': 'Return cart total',
            'kind': 'tool',
            'surfaces': <String, Object?>{
              'web.manifestShortcuts': <String, Object?>{'include': true},
              'web.protocolHandlers': <String, Object?>{'include': true},
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final output = const WebManifestEmitter().emit(
        existingManifestJson: baseManifest,
        manifest: agentManifest,
      );
      final map = jsonDecode(output) as Map<String, Object?>;
      final shortcuts = (map['shortcuts']! as List)
          .cast<Map<String, Object?>>();
      expect(shortcuts, hasLength(1));
      expect(shortcuts.first['url'], '/agent/invoke?name=app_cart_total');

      final handlers = (map['protocol_handlers']! as List)
          .cast<Map<String, Object?>>();
      expect(handlers, isNotEmpty);
      expect(handlers.first['protocol'], 'web+intentcall');
      expect(map['name'], 'demo');
    });

    test('matches golden manifest output', () {
      final output = const WebManifestEmitter().emit(
        existingManifestJson: _fixtureBaseWebManifest,
        manifest: _fixtureAgentManifest,
      );
      expect(output.trim(), _goldenWebManifest.trim());
    });

    test('honors web shortcut and protocol handler opt-outs', () {
      final output = const WebManifestEmitter().emit(
        existingManifestJson: _fixtureBaseWebManifest,
        manifest: AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'web',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_hidden',
              'namespace': 'app',
              'name': 'hidden',
              'description': 'Hidden',
              'kind': 'tool',
              'surfaces': <String, Object?>{
                'web.manifestShortcuts': <String, Object?>{'include': false},
                'web.protocolHandlers': <String, Object?>{'include': false},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
      );

      final map = jsonDecode(output) as Map<String, Object?>;
      expect(map['shortcuts'], isEmpty);
      expect(map['protocol_handlers'], isEmpty);
    });
  });

  group('WebMcpJsEmitter', () {
    test('emits feature-detect registerTool loop', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, contains('doc && doc.modelContext'));
      expect(js, contains('nav && nav.modelContext'));
      expect(js, contains('registerTool'));
      expect(js, contains('app_cart_total'));
      expect(js, contains('encodeURIComponent(name)'));
      expect(js, contains('application/json'));
      expect(js, contains('__intentcallWebMcpDartExecute'));
      expect(js, contains('validateInput'));
      expect(js, contains('Unknown property'));
      expect(js, contains('validateValue'));
      expect(js, contains('fallbackEnabled = false'));
      expect(js, contains('runtime_unavailable'));
    });

    test('emits opt-in network fallback', () {
      final js = const WebMcpJsEmitter(
        fallbackPolicy: WebMcpFallbackPolicy.enabled(
          invokePath: '/secure-agent/invoke',
        ),
      ).emit(_fixtureAgentManifest);
      expect(js, contains('fallbackEnabled = true'));
      expect(js, contains('"/secure-agent/invoke"'));
      expect(js, contains('global.fetch(invokePath'));
    });

    test('emits array items object validation', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, contains('validateArrayItems'));
      expect(js, contains('validateObjectProperties'));
      expect(js, contains('must be an object.'));
      expect(js, contains('Missing required property "'));
    });

    test('emits additionalProperties guard in validateInput', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_strict',
            'namespace': 'app',
            'name': 'strict',
            'description': 'strict schema',
            'kind': 'tool',
            'inputSchema': <String, Object?>{
              'type': 'object',
              'additionalProperties': false,
              'properties': <String, Object?>{
                'n': <String, Object?>{
                  'type': 'integer',
                  'minimum': 0,
                  'maximum': 10,
                },
              },
            },
          },
        ],
      });
      final js = const WebMcpJsEmitter().emit(manifest);
      expect(js, contains('additionalProperties === false'));
      expect(js, contains('Unknown property'));
      expect(js, contains('validateNumericBounds'));
    });

    test('emits Dart hook before opt-in fetch fallback', () {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);
      expect(js, contains('global.__intentcallWebMcpDartExecute'));
      expect(js, contains('return fetchInvoke(tool.name, args);'));
    });

    test('default runtime unavailable does not call fetch', () async {
      final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);

      final result = await _runWebMcpJs(js);

      expect(result['fetchCalled'], isFalse);
      expect(result['toolCount'], 1);
      expect(result['result'], isA<Map>());
      expect((result['result']! as Map)['ok'], isFalse);
      expect((result['result']! as Map)['code'], 'runtime_unavailable');
    });

    test(
      'default runtime unavailable does not fetch after null Dart hook',
      () async {
        final js = const WebMcpJsEmitter().emit(_fixtureAgentManifest);

        final result = await _runWebMcpJs(
          js,
          dartHook: 'async function () { return null; }',
        );

        expect(result['fetchCalled'], isFalse);
        expect((result['result']! as Map)['code'], 'runtime_unavailable');
      },
    );

    test('opt-in runtime fallback calls configured fetch path', () async {
      final js = const WebMcpJsEmitter(
        fallbackPolicy: WebMcpFallbackPolicy.enabled(
          invokePath: '/secure-agent/invoke',
        ),
      ).emit(_fixtureAgentManifest);

      final result = await _runWebMcpJs(js);

      expect(result['fetchCalled'], isTrue);
      expect(result['fetchUrl'], '/secure-agent/invoke?name=app_cart_total');
      expect((result['result']! as Map)['via'], 'fetch');
    });

    test('skips non-tool intents', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_errors',
            'namespace': 'app',
            'name': 'errors',
            'description': 'errors resource',
            'kind': 'resource',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      final js = const WebMcpJsEmitter().emit(manifest);
      expect(js, isNot(contains('app_errors')));
      expect(js, contains('var tools = ['));
      expect(js, contains('];'));
      expect(js.split('var tools = [').last.split('];').first.trim(), isEmpty);
    });

    test('honors web.webMcp opt-out', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_hidden',
            'namespace': 'app',
            'name': 'hidden',
            'description': 'Hidden',
            'kind': 'tool',
            'surfaces': <String, Object?>{
              'web.webMcp': <String, Object?>{'include': false},
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final js = const WebMcpJsEmitter().emit(manifest);
      expect(js, isNot(contains('app_hidden')));
      expect(js.split('var tools = [').last.split('];').first.trim(), isEmpty);
    });
  });

  group('AgentManifest', () {
    test('reads entityTypes with neutral snapshot fields', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'entityTypes': [
          <String, Object?>{
            'qualifiedName': 'app_project',
            'namespace': 'app',
            'name': 'project',
            'displayName': 'Project',
            'pluralDisplayName': 'Projects',
            'description': 'A project snapshot',
            'idKey': 'id',
            'titleKey': 'name',
            'subtitleKey': 'summary',
            'keywordsKey': 'tags',
            'urlKey': 'url',
            'defaultQueryLimit': 12,
            'snapshotSchema': <String, Object?>{
              'type': 'object',
              'required': <String>['id', 'name'],
            },
          },
        ],
        'tools': const <Object?>[],
      });

      expect(manifest.entityTypes, hasLength(1));
      final entityType = manifest.entityTypes.first;
      expect(entityType.qualifiedName, 'app_project');
      expect(entityType.displayName, 'Project');
      expect(entityType.pluralDisplayName, 'Projects');
      expect(entityType.titleKey, 'name');
      expect(entityType.subtitleKey, 'summary');
      expect(entityType.keywordsKey, 'tags');
      expect(entityType.defaultQueryLimit, 12);
      expect(entityType.snapshotSchema['required'], isA<List>());
      expect(entityType.toJson()['entityKind'], isNull);
    });

    test('rejects malformed entityTypes entries', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'web',
          'entityTypes': [
            <String, Object?>{
              'qualifiedName': 'app_project',
              'namespace': 'app',
              'name': 'project',
              'displayName': 'Project',
              'titleKey': 'bad.key',
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('mergeManifest passes through raw entityTypes', () {
      final manifest = const ManifestMerger().mergeManifest(
        catalog: const <AgentRegistryCatalogEntry>[],
        policy: const ProjectionPolicy(),
        entityTypes: [
          <String, Object?>{
            'qualifiedName': 'app_project',
            'namespace': 'app',
            'name': 'project',
            'displayName': 'Project',
          },
        ],
        platform: 'web',
      );

      expect(manifest.platform, 'web');
      expect(manifest.entityTypes, hasLength(1));
      expect(manifest.entityTypes.single.qualifiedName, 'app_project');
    });

    test('reads shortcuts and intents arrays', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'android',
        'shortcuts': [
          <String, Object?>{
            'qualifiedName': 'app_ping',
            'namespace': 'app',
            'name': 'ping',
            'description': 'ping',
            'kind': 'tool',
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      expect(manifest.entries, hasLength(1));
      expect(manifest.tools.first.qualifiedName, 'app_ping');
    });

    test('reads surfaces with boolean and object exposure', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'web',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_ping',
            'namespace': 'app',
            'name': 'ping',
            'description': 'ping',
            'kind': 'tool',
            'surfaces': <String, Object?>{
              'web.webMcp': false,
              'web.protocolHandlers': <String, Object?>{
                'include': true,
                'note': 'kept',
              },
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });
      final entry = manifest.tools.first;
      expect(
        entry.surfaces.includes(
          AgentManifestSurface.webMcp,
          defaultValue: true,
        ),
        isFalse,
      );
      expect(
        entry
            .surfaces
            .overrides[AgentManifestSurface.webProtocolHandlers]
            ?.options['note'],
        'kept',
      );
      expect(entry.toJson()['surfaces'], isA<Map<String, Object?>>());
    });

    test('rejects unknown surface keys', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'web',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_ping',
              'namespace': 'app',
              'name': 'ping',
              'description': 'ping',
              'kind': 'tool',
              'surfaces': <String, Object?>{'web.unknown': true},
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects non-boolean surface include', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'web',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_ping',
              'namespace': 'app',
              'name': 'ping',
              'description': 'ping',
              'kind': 'tool',
              'surfaces': <String, Object?>{
                'web.webMcp': <String, Object?>{'include': 'yes'},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('reads nativeInline runtime metadata', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'apple',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_inline',
            'namespace': 'app',
            'name': 'inline',
            'description': 'inline',
            'kind': 'tool',
            'dispatchMode': 'inlineRuntime',
            'inlineRuntime': <String, Object?>{
              'kind': 'nativeInline',
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'mainApp'},
              },
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final inlineRuntime = manifest.tools.first.inlineRuntime;
      expect(inlineRuntime?.kind, AgentManifestInlineRuntimeKind.nativeInline);
      expect(
        inlineRuntime?.platforms.apple?.target,
        AgentManifestAppleInlineRuntimeTarget.mainApp,
      );
      expect(manifest.tools.first.toJson()['inlineRuntime'], isA<Map>());
    });

    test('reads inline runtime typed result metadata', () {
      final manifest = AgentManifest.fromJson(<String, Object?>{
        'version': 1,
        'platform': 'apple',
        'tools': [
          <String, Object?>{
            'qualifiedName': 'app_inline',
            'namespace': 'app',
            'name': 'inline',
            'description': 'inline',
            'kind': 'tool',
            'dispatchMode': 'inlineRuntime',
            'inlineRuntime': <String, Object?>{
              'kind': 'dartExtensionInline',
              'result': <String, Object?>{'type': 'number', 'dataKey': 'total'},
              'platforms': <String, Object?>{
                'apple': <String, Object?>{'target': 'appIntentsExtension'},
              },
            },
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
      });

      final result = manifest.tools.first.inlineRuntime?.result;
      expect(result?.type, AgentManifestInlineRuntimeResultType.number);
      expect(result?.dataKey, 'total');
      expect(
        (manifest.tools.first.toJson()['inlineRuntime']! as Map)['result'],
        isA<Map>(),
      );
    });

    test('rejects inlineRuntime config without inline dispatch mode', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'inline',
              'kind': 'tool',
              'dispatchMode': 'openApp',
              'inlineRuntime': <String, Object?>{'kind': 'nativeInline'},
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown inline runtime kind', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'inline',
              'kind': 'tool',
              'dispatchMode': 'inlineRuntime',
              'inlineRuntime': <String, Object?>{'kind': 'unknownInline'},
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown Apple inline runtime target', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'inline',
              'kind': 'tool',
              'dispatchMode': 'inlineRuntime',
              'inlineRuntime': <String, Object?>{
                'kind': 'nativeInline',
                'platforms': <String, Object?>{
                  'apple': <String, Object?>{'target': 'sidecar'},
                },
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown inline runtime typed result type', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'inline',
              'kind': 'tool',
              'dispatchMode': 'inlineRuntime',
              'inlineRuntime': <String, Object?>{
                'kind': 'nativeInline',
                'result': <String, Object?>{'type': 'object'},
                'platforms': <String, Object?>{
                  'apple': <String, Object?>{'target': 'mainApp'},
                },
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects unsafe inline runtime typed result data key', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_inline',
              'namespace': 'app',
              'name': 'inline',
              'description': 'inline',
              'kind': 'tool',
              'dispatchMode': 'inlineRuntime',
              'inlineRuntime': <String, Object?>{
                'kind': 'dartExtensionInline',
                'result': <String, Object?>{
                  'type': 'string',
                  'dataKey': 'bad.key',
                },
                'platforms': <String, Object?>{
                  'apple': <String, Object?>{'target': 'appIntentsExtension'},
                },
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects removed includeInShortcuts even with surfaces present', () {
      expect(
        () => AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'apple',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_ping',
              'namespace': 'app',
              'name': 'ping',
              'description': 'ping',
              'kind': 'tool',
              'includeInShortcuts': true,
              'surfaces': <String, Object?>{
                'apple.appShortcuts': <String, Object?>{'include': false},
              },
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

Future<Map<String, Object?>> _runWebMcpJs(
  final String js, {
  final String? dartHook,
}) async {
  final script =
      '''
Object.defineProperty(globalThis, 'document', {
  value: {
    modelContext: {
      registerTool(tool) {
        globalThis.__registered.push(tool);
      }
    }
  },
  configurable: true
});
Object.defineProperty(globalThis, 'navigator', {
  value: {},
  configurable: true
});
globalThis.__registered = [];
globalThis.__fetchCalled = false;
globalThis.__fetchUrl = null;
globalThis.fetch = async function(url) {
  globalThis.__fetchCalled = true;
  globalThis.__fetchUrl = url;
  return { json: async function() { return { ok: true, via: 'fetch' }; } };
};
${dartHook == null ? '' : 'globalThis.__intentcallWebMcpDartExecute = $dartHook;'}
$js
const result = await globalThis.__registered[0].execute({});
console.log(JSON.stringify({
  toolCount: globalThis.__registered.length,
  result,
  fetchCalled: globalThis.__fetchCalled,
  fetchUrl: globalThis.__fetchUrl
}));
''';
  final process = await Process.run('node', <String>[
    '--input-type=module',
    '-e',
    script,
  ]);
  if (process.exitCode != 0) {
    fail('node failed: ${process.stderr}\n${process.stdout}');
  }
  return (jsonDecode(process.stdout as String) as Map).cast<String, Object?>();
}

const _fixtureBaseWebManifest = '''
{
    "name": "test_app",
    "short_name": "test_app",
    "start_url": ".",
    "display": "standalone"
}
''';

final _fixtureAgentManifest = AgentManifest.fromJson(<String, Object?>{
  'version': 1,
  'platform': 'web',
  'tools': [
    <String, Object?>{
      'qualifiedName': 'app_cart_total',
      'namespace': 'app',
      'name': 'cart_total',
      'description': 'Return cart total',
      'kind': 'tool',
      'surfaces': <String, Object?>{
        'web.manifestShortcuts': <String, Object?>{'include': true},
        'web.protocolHandlers': <String, Object?>{'include': true},
        'web.webMcp': <String, Object?>{'include': true},
      },
      'inputSchema': <String, Object?>{'type': 'object'},
    },
  ],
});

const _goldenWebManifest = '''
{
    "name": "test_app",
    "short_name": "test_app",
    "start_url": ".",
    "display": "standalone",
    "shortcuts": [
        {
            "name": "Cart Total",
            "short_name": "Cart Total",
            "description": "Return cart total",
            "url": "/agent/invoke?name=app_cart_total"
        }
    ],
    "protocol_handlers": [
        {
            "protocol": "web+intentcall",
            "url": "/agent/invoke?protocol=%s"
        },
        {
            "protocol": "web+intentcall",
            "url": "/agent/invoke?name=app_cart_total&payload=%s"
        }
    ]
}''';
