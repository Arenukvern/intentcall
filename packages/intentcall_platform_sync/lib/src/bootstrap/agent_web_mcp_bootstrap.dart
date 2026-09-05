import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';
import 'agent_web_mcp_bootstrap_stub.dart'
    if (dart.library.js_interop) 'agent_web_mcp_bootstrap_web.dart'
    as impl;

/// Registers WebMCP tools from [AgentCallEntry] values (Flutter web path C).
///
/// The default policy is open only while Dart assertions are enabled. In
/// compiled profile/release builds it denies all invocations unless an app
/// passes an explicit source/name allowlist or confirmation policy.
void registerAgentWebMcpFromEntries(
  final Set<AgentCallEntry> entries, {
  final IntentCallAuthorizationPolicy policy =
      const IntentCallAuthorizationPolicy.debugAllowAll(),
  final ManifestSurfaceIndex? surfaceIndex,
}) => impl.registerFromEntries(
  entries,
  policy: policy,
  surfaceIndex: surfaceIndex,
);

/// Registers WebMCP tools directly from [registry] and executes them in Dart.
///
/// The default policy is open only while Dart assertions are enabled. In
/// compiled profile/release builds it denies all invocations unless an app
/// passes an explicit source/name allowlist or confirmation policy.
void registerAgentWebMcpFromRegistry(
  final AgentRegistry registry, {
  final IntentCallAuthorizationPolicy policy =
      const IntentCallAuthorizationPolicy.debugAllowAll(),
  final ManifestSurfaceIndex? surfaceIndex,
}) => impl.registerFromRegistry(
  registry,
  policy: policy,
  surfaceIndex: surfaceIndex,
);

/// Whether a tool was already registered on WebMCP (web only; stub returns false).
bool isAgentWebMcpToolRegistered(final String qualifiedName) =>
    impl.isAgentWebMcpToolRegistered(qualifiedName);
