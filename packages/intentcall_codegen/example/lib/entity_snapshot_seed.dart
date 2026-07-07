import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'generated/agent_catalog.g.dart';

/// Builds demo [AgentEntitySnapshot] rows for the generated project entity.
Iterable<AgentEntitySnapshot> demoProjectEntitySnapshots() sync* {
  if (agentEntityTypeDescriptors.isEmpty) {
    return;
  }
  final descriptor = agentEntityTypeDescriptors.single;
  yield AgentEntitySnapshot(
    ref: AgentEntityRef(
      namespace: descriptor.namespace,
      typeName: descriptor.name,
      identifier: 'project-1',
    ),
    title: 'Codegen project',
    subtitle: 'Entity snapshot seed',
    keywords: const <String>['demo', 'codegen'],
    properties: <String, Object?>{
      AppProjectEntityFields.name: 'Codegen project',
      AppProjectEntityFields.summary: 'Entity snapshot seed',
      AppProjectEntityFields.tags: <String>['demo', 'codegen'],
    },
  );
}

/// Projects demo snapshots through descriptor-aligned cache keys.
Map<String, Object?> demoProjectSnapshotRow() {
  final descriptor = agentEntityTypeDescriptors.single;
  return projectAgentEntitySnapshot(
    demoProjectEntitySnapshots().single,
    descriptor,
  );
}
