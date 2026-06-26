import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';

void registerFromEntries(
  final Set<AgentCallEntry> entries, {
  required final IntentCallAuthorizationPolicy policy,
}) {}

void registerFromRegistry(
  final AgentRegistry registry, {
  required final IntentCallAuthorizationPolicy policy,
}) {}

bool isAgentWebMcpToolRegistered(final String qualifiedName) => false;
