import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:test/test.dart';

const _appleAppIntentsOnly = <String, Object?>{
  'apple.appIntents': <String, Object?>{'include': true},
};

const _appleShortcutsOnly = <String, Object?>{
  'apple.appIntents': <String, Object?>{'include': false},
  'apple.appShortcuts': <String, Object?>{'include': true},
};

const _appleEntitiesAndSpotlight = <String, Object?>{
  'apple.entities': <String, Object?>{'include': true},
  'apple.spotlight': <String, Object?>{'include': true},
};

AgentManifest _appleManifest({
  required final Map<String, Object?> toolSurfaces,
  final List<Object?> entityTypes = const <Object?>[],
  final List<Object?> tools = const <Object?>[],
}) => AgentManifest.fromJson(<String, Object?>{
  'version': 1,
  'platform': 'apple',
  'protocolScheme': 'demoapp',
  if (entityTypes.isNotEmpty) 'entityTypes': entityTypes,
  'tools': tools.isNotEmpty
      ? tools
      : [
          <String, Object?>{
            'qualifiedName': 'app_ping',
            'namespace': 'app',
            'name': 'ping',
            'description': 'Ping',
            'kind': 'tool',
            'surfaces': toolSurfaces,
            'inputSchema': <String, Object?>{'type': 'object'},
          },
        ],
});

void main() {
  group('AppleSwiftAppIntentsEmitter surface matrix', () {
    test('appleAppIntents emits struct without shortcuts', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        _appleManifest(toolSurfaces: _appleAppIntentsOnly),
      );

      expect(swift, contains('struct AppPingIntent: AppIntent'));
      expect(swift, isNot(contains('AppShortcut(intent: AppPingIntent()')));
      expect(swift, contains('static var appShortcuts: [AppShortcut] {'));
      expect(swift, contains('return []'));
    });

    test('appleAppShortcuts without appleAppIntents emits no struct', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        _appleManifest(toolSurfaces: _appleShortcutsOnly),
      );

      expect(swift, isNot(contains('struct AppPingIntent: AppIntent')));
      expect(swift, isNot(contains('AppShortcut(intent: AppPingIntent()')));
      expect(swift, contains('return []'));
    });

    test('appleAppShortcuts with appleAppIntents emits shortcut row only', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        _appleManifest(
          toolSurfaces: <String, Object?>{
            'apple.appIntents': <String, Object?>{'include': true},
            'apple.appShortcuts': <String, Object?>{'include': true},
          },
        ),
      );

      expect(swift, contains('struct AppPingIntent: AppIntent'));
      expect(swift, contains('AppShortcut(intent: AppPingIntent(), phrases:'));
    });

    test('appleEntities without spotlight omits CoreSpotlight and indexer', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        _appleManifest(
          toolSurfaces: <String, Object?>{
            'apple.entities': <String, Object?>{'include': true},
          },
          entityTypes: [
            <String, Object?>{
              'qualifiedName': 'app_project',
              'namespace': 'app',
              'name': 'project',
              'displayName': 'Project',
              'description': 'Open project',
            },
          ],
        ),
      );

      expect(swift, contains('struct AppProjectEntity: AppEntity {'));
      expect(swift, isNot(contains('IndexedEntity')));
      expect(swift, isNot(contains('import CoreSpotlight')));
      expect(swift, isNot(contains('IntentCallAppEntityIndexer')));
      expect(swift, contains('enum IntentCallGeneratedEntityConfig'));
      expect(swift, isNot(contains('enum IntentCallNativeEntitySnapshotStore {')));
      expect(swift, isNot(contains('enum IntentCallNativeHandoffStore {')));
    });

    test('appleSpotlight adds indexing helpers', () {
      final swift = const AppleSwiftAppIntentsEmitter().emit(
        _appleManifest(
          toolSurfaces: _appleEntitiesAndSpotlight,
          entityTypes: [
            <String, Object?>{
              'qualifiedName': 'app_project',
              'namespace': 'app',
              'name': 'project',
              'displayName': 'Project',
              'description': 'Open project',
            },
          ],
        ),
      );

      expect(
        swift,
        contains('struct AppProjectEntity: AppEntity, IndexedEntity'),
      );
      expect(swift, contains('import CoreSpotlight'));
      expect(swift, contains('enum IntentCallAppEntityIndexer'));
      expect(swift, contains('func reindexAllEntities('));
      expect(
        swift,
        contains('CSSearchableIndex.default().indexAppEntities'),
      );
    });
  });

  group('ProjectionPolicy apple defaults', () {
    test('ios enables appleAppIntents but not shortcuts or spotlight', () {
      const policy = ProjectionPolicy();
      final surfaces = policy.resolvedDefaultSurfaces(
        enabledPlatforms: ['ios'],
      );
      expect(
        surfaces.includes(AgentManifestSurface.appleAppIntents, defaultValue: false),
        isTrue,
      );
      expect(
        surfaces.includes(AgentManifestSurface.appleAppShortcuts, defaultValue: true),
        isFalse,
      );
      expect(
        surfaces.includes(AgentManifestSurface.appleSpotlight, defaultValue: true),
        isFalse,
      );
      expect(
        surfaces.includes(AgentManifestSurface.appleEntities, defaultValue: true),
        isFalse,
      );
    });
  });
}
