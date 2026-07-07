import 'package:intentcall_platform/src/flutter/intentcall_entity_index.dart';
import 'package:test/test.dart';

import '../lib/entity_snapshot_seed.dart';
import '../lib/generated/agent_catalog.g.dart';

void main() {
  test('upsertAgentSnapshotsForType seeds descriptor-aligned project row', () async {
    expect(agentEntityTypeDescriptors, hasLength(1));

    final calls = <String, Object?>{};
    final index = IntentCallPlatformEntityIndex(
      invoke: (final method, final arguments) async {
        calls[method] = arguments;
        return 1;
      },
    );
    final descriptor = agentEntityTypeDescriptors.single;

    final count = await index.upsertAgentSnapshotsForType(
      descriptor: descriptor,
      snapshots: demoProjectEntitySnapshots(),
    );

    expect(count, 1);
    final args = calls['upsertEntitySnapshots']! as Map<String, Object?>;
    expect(args['entityType'], 'app_project');
    final row = (args['snapshots']! as List).single as Map;
    expect(row['projectId'], 'project-1');
    expect(row['id'], 'project-1');
    expect(row['name'], 'Codegen project');
    expect(row['summary'], 'Entity snapshot seed');
    expect(row['tags'], ['demo', 'codegen']);
    expect(row['title'], 'Codegen project');
    expect(row['subtitle'], 'Entity snapshot seed');
    expect(row['keywords'], ['demo', 'codegen']);
  });
}
