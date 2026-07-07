import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';

void registerFromEntries(
  final Set<AgentCallEntry> entries, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) {}

void registerFromRegistry(
  final AgentRegistry registry, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) {}

bool isAgentWebMcpToolRegistered(final String qualifiedName) => false;
