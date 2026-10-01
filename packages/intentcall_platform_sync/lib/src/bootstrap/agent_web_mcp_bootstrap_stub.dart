import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';
import 'web_mcp_registration_report.dart';

WebMcpRegistrationReport registerFromEntries(
  final Set<AgentCallEntry> entries, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) => const WebMcpRegistrationReport.unavailable();

WebMcpRegistrationReport registerFromRegistry(
  final AgentRegistry registry, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) => const WebMcpRegistrationReport.unavailable();

bool isAgentWebMcpToolRegistered(final String qualifiedName) => false;
