import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Cross-layer alignment matrix from projection-pipeline-spec section 6.
void main() {
  group('projection pipeline alignment matrix', () {
    group('dense surfaces per tool in JSON', () {
      test('export emits all AgentManifestSurface keys with bool include', () {
        const merger = ManifestMerger();
        const policy = ProjectionPolicy();
        final manifest = merger.mergeManifest(
          catalog: [
            AgentRegistryCatalogEntry(
              registryKey: 'app_ping',
              descriptor: AgentIntentDescriptor(
                namespace: 'app',
                name: 'ping',
                description: 'Ping',
                kind: AgentIntentKind.tool,
                inputSchema: const <String, Object?>{'type': 'object'},
              ),
            ),
          ],
          policy: policy,
          enabledPlatforms: ['web'],
        );
        final json = manifest.entries.single.toJson();
        final surfaces = json['surfaces']! as Map<String, Object?>;
        expect(surfaces.length, AgentManifestSurface.values.length);
        for (final entry in surfaces.entries) {
          final exposure = entry.value! as Map<String, Object?>;
          expect(exposure['include'], isA<bool>());
        }
      });
    });

    group('web-only yaml scopes non-web surfaces off', () {
      test('partial defaults with platforms:[web] omit android/windows', () {
        const merger = ManifestMerger();
        const policy = ProjectionPolicy(
          defaultSurfaces: AgentManifestSurfacePolicy({
            AgentManifestSurface.webMcp: AgentManifestSurfaceExposure(
              include: true,
            ),
          }),
        );
        final manifest = merger.mergeManifest(
          catalog: [
            AgentRegistryCatalogEntry(
              registryKey: 'app_ping',
              descriptor: AgentIntentDescriptor(
                namespace: 'app',
                name: 'ping',
                description: 'Ping',
                kind: AgentIntentKind.tool,
                inputSchema: const <String, Object?>{'type': 'object'},
              ),
            ),
          ],
          policy: policy,
          enabledPlatforms: ['web'],
        );
        final surfaces = manifest.entries.single.surfaces;
        expect(
          surfaces.includes(AgentManifestSurface.webMcp, defaultValue: false),
          isTrue,
        );
        expect(
          surfaces.includes(
            AgentManifestSurface.androidShortcuts,
            defaultValue: true,
          ),
          isFalse,
        );
        expect(
          surfaces.includes(
            AgentManifestSurface.windowsProtocolActivation,
            defaultValue: true,
          ),
          isFalse,
        );
      });
    });

    group('emitter defaultValue:false excludes absent surfaces', () {
      test('WebMcpJsEmitter skips tools without web.webMcp include', () {
        final manifest = AgentManifest.fromJson(<String, Object?>{
          'version': 1,
          'platform': 'web',
          'tools': [
            <String, Object?>{
              'qualifiedName': 'app_visible',
              'namespace': 'app',
              'name': 'visible',
              'description': 'visible',
              'kind': 'tool',
              'inputSchema': <String, Object?>{'type': 'object'},
              'surfaces': <String, Object?>{
                'web.webMcp': <String, Object?>{'include': true},
              },
            },
            <String, Object?>{
              'qualifiedName': 'app_hidden',
              'namespace': 'app',
              'name': 'hidden',
              'description': 'hidden',
              'kind': 'tool',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        });

        final js = const WebMcpJsEmitter().emit(manifest);
        expect(js, contains('app_visible'));
        expect(js, isNot(contains('app_hidden')));
      });
    });

    group('sync uses layout.manifest and layout.webDir', () {
      test('PlatformSync resolves custom layout paths', () {
        final temp = Directory.systemTemp.createTempSync(
          'intentcall_projection_alignment_layout_',
        );
        addTearDown(() => temp.deleteSync(recursive: true));

        final assetsDir = Directory(p.join(temp.path, 'assets'))..createSync();
        final webDir = Directory(p.join(assetsDir.path, 'web'))..createSync();
        File(p.join(temp.path, 'intentcall.yaml')).writeAsStringSync('''
host: dart
layout:
  manifest: assets/agent_manifest.json
  webDir: assets/web
''');
        File(p.join(assetsDir.path, 'agent_manifest.json')).writeAsStringSync(
          '''
{
  "version": 1,
  "platform": "web",
  "tools": [
    {
      "qualifiedName": "app_ping",
      "namespace": "app",
      "name": "ping",
      "description": "Ping",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": true}
      }
    }
  ]
}
''',
        );
        File(p.join(webDir.path, 'manifest.json')).writeAsStringSync('''
{
  "name": "demo",
  "start_url": "."
}
''');

        const merger = ManifestMerger();
        expect(
          merger.readManifestRelativePath(temp.path),
          'assets/agent_manifest.json',
        );
        expect(merger.readWebDirRelativePath(temp.path), 'assets/web');

        const sync = PlatformSync();
        expect(
          sync.readManifest(temp.path).tools.single.qualifiedName,
          'app_ping',
        );
      });
    });

    group('Dart WebMCP subset of manifest web.webMcp', () {
      test('ManifestSurfaceIndex excludes web.webMcp:false tools', () {
        final manifest = AgentManifest.parse('''
{
  "version": 1,
  "platform": "web",
  "tools": [
    {
      "qualifiedName": "app_demo_ping",
      "namespace": "app",
      "name": "demo_ping",
      "description": "ping",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": true}
      }
    },
    {
      "qualifiedName": "app_demo_cart",
      "namespace": "app",
      "name": "demo_cart",
      "description": "cart",
      "kind": "tool",
      "inputSchema": {"type": "object"},
      "surfaces": {
        "web.webMcp": {"include": false}
      }
    }
  ]
}
''');
        final index = ManifestSurfaceIndex.fromManifest(manifest);
        expect(index.includesWebMcp('app_demo_ping'), isTrue);
        expect(index.includesWebMcp('app_demo_cart'), isFalse);
      });
    });

    group('apple shortcuts opt-in on ios', () {
      test('ios enabled keeps apple.appShortcuts false by default', () {
        const merger = ManifestMerger();
        const policy = ProjectionPolicy();
        final manifest = merger.mergeManifest(
          catalog: [
            AgentRegistryCatalogEntry(
              registryKey: 'app_ping',
              descriptor: AgentIntentDescriptor(
                namespace: 'app',
                name: 'ping',
                description: 'Ping',
                kind: AgentIntentKind.tool,
                inputSchema: const <String, Object?>{'type': 'object'},
              ),
            ),
          ],
          policy: policy,
          enabledPlatforms: ['ios'],
        );
        final surfaces = manifest.entries.single.surfaces;
        expect(
          surfaces.includes(
            AgentManifestSurface.appleAppShortcuts,
            defaultValue: true,
          ),
          isFalse,
        );
        expect(
          surfaces.includes(
            AgentManifestSurface.appleAppIntents,
            defaultValue: false,
          ),
          isTrue,
        );
      });
    });

    group('apple struct gated separately from shortcuts', () {
      test('appleAppIntents emits struct without shortcuts row', () {
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
                'inputSchema': <String, Object?>{'type': 'object'},
                'surfaces': <String, Object?>{
                  'apple.appIntents': <String, Object?>{'include': true},
                  'apple.appShortcuts': <String, Object?>{'include': false},
                },
              },
            ],
          }),
        );

        expect(swift, contains('struct AppPingIntent: AppIntent'));
        expect(swift, isNot(contains('AppShortcut(intent: AppPingIntent()')));
      });
    });

    group('entityTypes in export', () {
      test('mergeManifest passes entityTypes through to manifest', () {
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

        expect(manifest.entityTypes, hasLength(1));
        expect(manifest.entityTypes.single.qualifiedName, 'app_project');
      });
    });

    group('single native entity snapshot store', () {
      test(
        'Apple emitter configures shared IntentCallNativeEntitySnapshotStore',
        () {
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
                },
              ],
              'tools': [
                <String, Object?>{
                  'qualifiedName': 'app_ping',
                  'namespace': 'app',
                  'name': 'ping',
                  'description': 'Ping',
                  'kind': 'tool',
                  'inputSchema': <String, Object?>{'type': 'object'},
                  'surfaces': <String, Object?>{
                    'apple.entities': <String, Object?>{'include': true},
                  },
                },
              ],
            }),
          );

          expect(swift, contains('enum IntentCallGeneratedEntityConfig'));
          expect(
            swift,
            contains('IntentCallNativeEntitySnapshotStore.fallbackScheme'),
          );
          expect(
            swift,
            isNot(contains('enum IntentCallNativeEntitySnapshotStore {')),
          );
        },
      );
    });

    group('mcp_flutter three-gate (sibling consumer)', () {
      // Three-gate spine (semantics unchanged across hosts):
      //   1. dart run build_runner build --delete-conflicting-outputs
      //   2. intentcall manifest export --check
      //   3. intentcall platform sync --platform <resolved> --check
      //
      // mcp_flutter Jaspr recipe: `make check-contracts` →
      //   tool/contracts/check_intentcall_jaspr_three_gate.sh
      // Flutter consumer: `tool/contracts/check_intentcall_hosted_consumer.sh`
      test(
        'skipped in agentkit — run make check-contracts in mcp_flutter',
        () {},
        skip:
            'L5b/L5c: mcp_flutter Jaspr + flutter_test_app gates run in sibling repo (make check-contracts)',
      );
    });
  });
}
