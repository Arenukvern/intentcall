import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_entity_type_descriptor.dart';

abstract interface class AgentEntityProvider {
  AgentEntityTypeDescriptor get descriptor;

  Future<AgentEntitySnapshot?> resolve(final AgentEntityRef ref);

  Future<Iterable<AgentEntitySnapshot>> suggest(
    final String text, {
    final int limit = 10,
  });

  Future<Iterable<AgentEntitySnapshot>> search(
    final String text, {
    final int limit = 10,
  });
}
