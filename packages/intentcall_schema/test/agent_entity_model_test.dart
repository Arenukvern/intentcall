import 'dart:convert';

import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('AgentEntityRef round trips JSON', () {
    const ref = AgentEntityRef(
      namespace: 'notes',
      typeName: 'note',
      identifier: 'note-1',
    );

    expect(AgentEntityRef.fromJson(ref.toJson()), ref);
    expect(ref.toJson(), <String, Object?>{
      'namespace': 'notes',
      'type_name': 'note',
      'identifier': 'note-1',
    });
  });

  test('AgentEntitySnapshot round trips JSON-safe properties', () {
    final snapshot = AgentEntitySnapshot(
      ref: const AgentEntityRef(
        namespace: 'notes',
        typeName: 'note',
        identifier: 'note-1',
      ),
      title: 'Inbox note',
      subtitle: 'Follow up today',
      keywords: const <String>['work', 'today'],
      thumbnailUrl: 'https://example.test/thumb.png',
      url: 'https://example.test/notes/note-1',
      displayName: 'Inbox note',
      deepLink: 'intentcall://notes/note-1',
      updatedAt: DateTime.utc(2026, 6, 29, 12),
      version: 'rev-7',
      freshness: 'fresh',
      properties: const <String, Object?>{
        'title': 'Inbox note',
        'pinned': true,
        'rank': 3,
        'tags': <Object?>['work', 'today'],
        'metadata': <String, Object?>{'color': 'blue'},
      },
    );

    final encoded = jsonEncode(snapshot.toJson());
    final decoded = Map<String, Object?>.from(jsonDecode(encoded) as Map);

    expect(AgentEntitySnapshot.fromJson(decoded), snapshot);
  });

  test('AgentEntitySnapshot rejects non-JSON property values', () {
    expect(
      () => AgentEntitySnapshot(
        ref: const AgentEntityRef(
          namespace: 'notes',
          typeName: 'note',
          identifier: 'note-1',
        ),
        properties: <String, Object?>{'created_at': DateTime(2026)},
      ),
      throwsArgumentError,
    );
  });
}
