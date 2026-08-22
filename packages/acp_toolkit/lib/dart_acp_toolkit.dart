/// ACP server library.
///
/// Exposes a stdio JSON-RPC 2.0 server implementing the Agent Client
/// Protocol v1 baseline: `initialize`, `session/new`, `session/prompt`,
/// `session/cancel`, plus `session/update` notifications and
/// `session/request_permission` callbacks. Agent behavior is supplied by an
/// [AcpAgentBackend] implementation, keeping this library transport- and
/// model-agnostic.
library;

export 'src/acp_agent_backend.dart';
export 'src/acp_types.dart';
export 'src/acp_stdio_server.dart';
export 'src/echo_backend.dart';
export 'src/registry_acp_backend.dart';
