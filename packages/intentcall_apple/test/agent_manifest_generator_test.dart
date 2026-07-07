import 'dart:convert';

import 'package:intentcall_apple/intentcall_apple.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:test/test.dart';

void main() {
  test('generateAppleAgentManifest includes tool and resource intents', () {
    final json = generateAppleAgentManifest([
      AgentIntentDescriptor(
        namespace: 'fmt',
        name: 'wait_for',
        description: 'wait',
        kind: AgentIntentKind.tool,
        inputSchema: const <String, Object?>{'type': 'object'},
      ),
      AgentIntentDescriptor(
        namespace: 'app',
        name: 'diagnostics',
        description: 'diag',
        kind: AgentIntentKind.resource,
        inputSchema: const <String, Object?>{'type': 'object'},
        mimeType: 'application/json',
      ),
    ], protocolScheme: 'demoapp');

    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['platform'], 'apple');
    final intents = map['intents']! as List;
    expect(intents, hasLength(2));
    expect(
      (intents[1] as Map)['resourceUri'],
      'demoapp://resource/diagnostics',
    );
  });

  test('generateAppleAgentManifest includes raw entityTypes section', () {
    final json = generateAppleAgentManifest(
      <AgentIntentDescriptor>[],
      entityTypes: [
        <String, Object?>{
          'qualifiedName': 'app_project',
          'namespace': 'app',
          'name': 'project',
          'displayName': 'Project',
          'titleKey': 'name',
        },
      ],
    );

    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['platform'], 'apple');
    final entityTypes = map['entityTypes']! as List;
    expect(entityTypes, hasLength(1));
    expect((entityTypes.first as Map)['titleKey'], 'name');
  });

  test('generateAppleAgentManifest projects core entity descriptors', () {
    final json = generateAppleAgentManifest(
      <AgentIntentDescriptor>[],
      entityTypeDescriptors: [
        AgentEntityTypeDescriptor(
          namespace: 'app',
          name: 'project',
          identifierName: 'project_id',
          displayName: 'Project',
          properties: [
            AgentEntityPropertyDescriptor(
              name: 'name',
              valueType: AgentEntityPropertyValueType.string,
              isDisplay: true,
              isSearchable: true,
              isIndexed: true,
            ),
            AgentEntityPropertyDescriptor(
              name: 'summary',
              valueType: AgentEntityPropertyValueType.string,
              isSearchable: true,
            ),
            AgentEntityPropertyDescriptor(
              name: 'tags',
              valueType: AgentEntityPropertyValueType.array,
              isSearchable: true,
            ),
          ],
        ),
      ],
    );

    final map = jsonDecode(json) as Map<String, Object?>;
    final entityTypes = map['entityTypes']! as List;
    final entityType = entityTypes.first as Map;
    expect(entityType['qualifiedName'], 'app_project');
    expect(entityType['idKey'], 'project_id');
    expect(entityType['titleKey'], 'name');
    expect(entityType['subtitleKey'], 'summary');
    expect(entityType['keywordsKey'], 'tags');
    expect((entityType['snapshotSchema']! as Map)['required'], ['project_id']);
  });
}
