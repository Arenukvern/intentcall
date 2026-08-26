/// ACP server + client library.
///
/// Exposes a stdio JSON-RPC 2.0 [AcpStdioServer] implementing the Agent
/// Client Protocol v1 baseline (`initialize`, `session/new`,
/// `session/prompt`, `session/cancel`, `session/update` notifications,
/// `session/request_permission` callbacks) with pluggable
/// [AcpAgentBackend]s, plus an [AcpClient] for driving external agents as a
/// client (spawn subprocess, run prompt turns, stream updates, answer
/// permission requests).
library;

export 'src/acp_agent_backend.dart';
export 'src/acp_client.dart';
export 'src/acp_types.dart';
export 'src/acp_stdio_server.dart';
export 'src/echo_backend.dart';
export 'src/registry_acp_backend.dart';
