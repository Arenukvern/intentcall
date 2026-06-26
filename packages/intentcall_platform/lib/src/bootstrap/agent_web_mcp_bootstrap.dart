import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import 'agent_web_mcp_bootstrap_stub.dart'
    if (dart.library.js_interop) 'agent_web_mcp_bootstrap_web.dart'
    as impl;

/// Registers WebMCP tools from [AgentCallEntry] values (Flutter web path C).
void registerAgentWebMcpFromEntries(final Set<AgentCallEntry> entries) =>
    impl.registerFromEntries(entries);

/// Registers WebMCP tools directly from [registry] and executes them in Dart.
void registerAgentWebMcpFromRegistry(
  final AgentRegistry registry, {
  final IntentCallAuthorizationPolicy policy =
      const IntentCallAuthorizationPolicy.allowAll(),
}) => impl.registerFromRegistry(registry, policy: policy);

/// Whether a tool was already registered on WebMCP (web only; stub returns false).
bool isAgentWebMcpToolRegistered(final String qualifiedName) =>
    impl.isAgentWebMcpToolRegistered(qualifiedName);
