import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_entity_provider.dart';

abstract interface class AgentEntityIndex {
  Future<void> upsert(final AgentEntitySnapshot snapshot);

  Future<void> delete(final AgentEntityRef ref);

  Future<void> reindex(final AgentEntityProvider provider);
}
