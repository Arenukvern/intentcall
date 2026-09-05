import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:test/test.dart';

void main() {
  test('buildProperties maps values onto descriptor field names', () {
    final descriptor = AgentEntityTypeDescriptor(
      namespace: 'app',
      name: 'project',
      identifierName: 'projectId',
      properties: [
        AgentEntityPropertyDescriptor(
          name: 'name',
          valueType: AgentEntityPropertyValueType.string,
          role: AgentEntityPropertyRole.title,
        ),
        AgentEntityPropertyDescriptor(
          name: 'summary',
          valueType: AgentEntityPropertyValueType.string,
          role: AgentEntityPropertyRole.subtitle,
        ),
      ],
    );
    final builder = AgentEntitySnapshotBuilder(descriptor);
    final row = builder.buildProperties(
      identifier: 'p-1',
      values: <String, Object?>{
        'name': 'Launch',
        'summary': 'Q3 launch',
        'ignored': 'not in descriptor',
      },
    );

    expect(row['projectId'], 'p-1');
    expect(row['name'], 'Launch');
    expect(row['summary'], 'Q3 launch');
    expect(row.containsKey('ignored'), isFalse);
    expect(builder.keys.titleKey, 'name');
    expect(builder.keys.subtitleKey, 'summary');
  });
}
