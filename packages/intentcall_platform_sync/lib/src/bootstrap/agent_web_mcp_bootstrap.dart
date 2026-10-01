import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';
import 'agent_web_mcp_bootstrap_stub.dart'
    if (dart.library.js_interop) 'agent_web_mcp_bootstrap_web.dart'
    as impl;
import 'web_mcp_registration_report.dart';

export 'web_mcp_registration_report.dart';

/// Projects [AgentCallEntry] values onto the WebMCP registry (Flutter web
/// path C). Verb-first name: this projects the toolkit's dynamic entries to
/// the browser surface; "Agent" jargon dropped (mcp_flutter ADR-0016
/// upstream plan; the pre-rename aliases were removed unreleased).
///
/// The default policy is open only while Dart assertions are enabled. In
/// compiled profile/release builds it denies all invocations unless an app
/// passes an explicit source/name allowlist or confirmation policy.
WebMcpRegistrationReport projectEntriesToWebMcp(
  final Set<AgentCallEntry> entries, {
  final IntentCallAuthorizationPolicy policy =
      const IntentCallAuthorizationPolicy.debugAllowAll(),
  final ManifestSurfaceIndex? surfaceIndex,
}) => impl.registerFromEntries(
  entries,
  policy: policy,
  surfaceIndex: surfaceIndex,
);

/// Projects [registry] onto the WebMCP registry and executes tools in Dart.
///
/// The default policy is open only while Dart assertions are enabled. In
/// compiled profile/release builds it denies all invocations unless an app
/// passes an explicit source/name allowlist or confirmation policy.
WebMcpRegistrationReport projectRegistryToWebMcp(
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
