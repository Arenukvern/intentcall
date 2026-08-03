import 'package:intentcall_schema/src/agent_result.dart';

import '../entity/agent_entity_type_descriptor.dart';
import '../intent/agent_intent_descriptor.dart';
import '../intent/registered_agent_intent.dart';
import 'agent_registry.dart';
import 'registry_events.dart';

/// https://agenticresourcediscovery.org
/// https://agenticresourcediscovery.org/how_ard_works/#5-reach-it-from-a-chatbot
// TODO(arenukvern): maybe add adr as unified surface?
class ARDRegistry implements AgentRegistry {
  @override
  // TODO: implement events
  Stream<AgentRegistryEvent> get events => throw UnimplementedError();

  @override
  RegisteredAgentIntent? get(final String qualifiedName) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  AgentEntityTypeDescriptor? getEntityType(final String qualifiedName) {
    // TODO: implement getEntityType
    throw UnimplementedError();
  }

  @override
  Future<AgentResult> invoke(
    final String qualifiedName,
    final AgentArguments arguments, {
    final String? correlationId,
  }) {
    // TODO: implement invoke
    throw UnimplementedError();
  }

  @override
  Iterable<AgentIntentDescriptor> listDescriptors({final String? namespace}) {
    // TODO: implement listDescriptors
    throw UnimplementedError();
  }

  @override
  Iterable<AgentEntityTypeDescriptor> listEntityTypes({
    final String? namespace,
  }) {
    // TODO: implement listEntityTypes
    throw UnimplementedError();
  }

  @override
  Iterable<AgentRegistryEntry> listEntries({final String? namespace}) {
    // TODO: implement listEntries
    throw UnimplementedError();
  }

  @override
  String qualify({
    required final String namespace,
    required final String name,
  }) {
    // TODO: implement qualify
    throw UnimplementedError();
  }

  @override
  void register(
    final RegisteredAgentIntent intent, {
    final String? qualifiedNameOverride,
  }) {
    // TODO: implement register
  }

  @override
  void registerEntityType(final AgentEntityTypeDescriptor descriptor) {
    // TODO: implement registerEntityType
  }

  @override
  void unregister(final String qualifiedName) {
    // TODO: implement unregister
  }

  @override
  void unregisterEntityType(final String qualifiedName) {
    // TODO: implement unregisterEntityType
  }
}
