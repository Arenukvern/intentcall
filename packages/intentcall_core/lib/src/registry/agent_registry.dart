import 'package:intentcall_schema/intentcall_schema.dart';

import '../intent/agent_intent_descriptor.dart';
import '../intent/registered_agent_intent.dart';
import 'registry_events.dart';

final class AgentRegistryEntry {
  const AgentRegistryEntry({required this.key, required this.intent});

  final String key;
  final RegisteredAgentIntent intent;

  AgentIntentDescriptor get descriptor => intent.descriptor;
}

abstract interface class AgentRegistry {
  String qualify({required final String namespace, required final String name});

  void register(
    final RegisteredAgentIntent intent, {
    final String? qualifiedNameOverride,
  });

  void unregister(final String qualifiedName);

  RegisteredAgentIntent? get(final String qualifiedName);

  Iterable<AgentRegistryEntry> listEntries({final String? namespace});

  Iterable<AgentIntentDescriptor> listDescriptors({final String? namespace});

  Future<AgentResult> invoke(
    final String qualifiedName,
    final AgentArguments arguments, {
    final String? correlationId,
  });

  Stream<AgentRegistryEvent> get events;
}
