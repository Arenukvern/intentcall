import 'dart:convert';

import 'package:intentcall_platform/intentcall_platform.dart';
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
  });

  group('AgentManifest', () {
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
  });
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
