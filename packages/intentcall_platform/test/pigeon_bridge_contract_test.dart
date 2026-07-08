import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/src/flutter/intentcall_entity_index.dart';
import 'package:intentcall_platform/src/flutter/intentcall_entity_key_bundle.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Pigeon bridge contract', () {
    test('invocation envelope DTO is declared in pigeon IDL', () {
      final idl = _readRepoFile(
        'packages/intentcall_bridge/pigeons/intentcall_platform_bridge.dart',
      );

      expect(idl, contains('class IntentCallInvocationEnvelopeDto'));
      expect(idl, contains('String id;'));
      expect(idl, contains('String qualifiedName;'));
      expect(idl, contains('Map<String?, Object?>? arguments;'));
      expect(idl, contains('String source;'));
      expect(idl, contains('String createdAt;'));
    });

    test('entity key bundle defaults match legacy channel keys', () {
      final keys = intentCallDefaultEntityKeyBundle();

      expect(keys.idKey, 'id');
      expect(keys.titleKey, 'title');
      expect(keys.subtitleKey, 'subtitle');
      expect(keys.keywordsKey, 'keywords');
    });

    test('entity index forwards descriptor-aware key bundle', () async {
      final calls = <String, Object?>{};
      final index = IntentCallPlatformEntityIndex(
        invoke: (final method, final arguments) async {
          calls[method] = arguments;
          return 1;
        },
      );
      final descriptor = AgentEntityTypeDescriptor(
        namespace: 'projects',
        name: 'project',
        identifierName: 'projectId',
        properties: [
          AgentEntityPropertyDescriptor(
            name: 'name',
            valueType: AgentEntityPropertyValueType.string,
            role: AgentEntityPropertyRole.title,
            isDisplay: true,
          ),
          AgentEntityPropertyDescriptor(
            name: 'summary',
            valueType: AgentEntityPropertyValueType.string,
            role: AgentEntityPropertyRole.subtitle,
            isSearchable: true,
          ),
          AgentEntityPropertyDescriptor(
            name: 'tags',
            valueType: AgentEntityPropertyValueType.array,
            role: AgentEntityPropertyRole.keywords,
            isIndexed: true,
          ),
        ],
      );

      await index.upsertAgentSnapshotsForType(
        descriptor: descriptor,
        snapshots: [
          AgentEntitySnapshot(
            ref: const AgentEntityRef(
              namespace: 'projects',
              typeName: 'project',
              identifier: 'project-1',
            ),
            title: 'Launch project',
            properties: const <String, Object?>{
              'name': 'Launch project',
              'summary': 'Descriptor-owned summary',
              'tags': <String>['launch'],
            },
          ),
        ],
      );

      final args = calls['upsertEntitySnapshots']! as Map<String, Object?>;
      final keys = args['keys']! as IntentCallEntityKeyBundle;
      expect(keys.idKey, 'projectId');
      expect(keys.titleKey, 'name');
      expect(keys.subtitleKey, 'summary');
      expect(keys.keywordsKey, 'tags');
    });

    test('generated host APIs expose invocation and entity surfaces', () {
      final generated = _readRepoFile(
        'packages/intentcall_bridge/lib/src/intentcall_platform_bridge.g.dart',
      );

      expect(generated, contains('class IntentCallInvocationsHostApi'));
      expect(generated, contains('takePendingInvocations()'));
      expect(generated, contains('class IntentCallEntitiesHostApi'));
      expect(generated, contains('upsertEntitySnapshots('));
      expect(generated, contains('deleteEntitySnapshots('));
      expect(generated, contains('clearEntityTypeSnapshots('));
      expect(generated, contains('listEntitySnapshots('));
      expect(generated, contains('searchEntitySnapshots('));
      expect(
        generated,
        contains(
          'dev.flutter.pigeon.intentcall_bridge.IntentCallInvocationsHostApi.takePendingInvocations',
        ),
      );
    });
  });
}

String _readRepoFile(final String relativePath) {
  final repoRoot = _findRepoRoot(Directory.current);
  return File(p.join(repoRoot.path, relativePath)).readAsStringSync();
}

Directory _findRepoRoot(Directory start) {
  var dir = start;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: intentcall_workspace')) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return start;
    }
    dir = parent;
  }
}
