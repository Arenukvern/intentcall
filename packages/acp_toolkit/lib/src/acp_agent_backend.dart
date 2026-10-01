import 'dart:async';

import 'acp_types.dart';

/// Pluggable agent behavior for the ACP server.
///
/// Implement this to drive any inference backend. The server owns the
/// JSON-RPC transport and protocol lifecycle; the backend owns sessions,
/// generation, and tool execution.
abstract interface class AcpAgentBackend {
  String get name;
  String get version;

  /// Capabilities advertised in the initialize response.
  Map<String, Object?> get agentCapabilities;

  /// Creates a session rooted at [request.cwd].
  Future<String> createSession(AcpSessionNewRequest request);

  /// Runs one prompt turn. Emit [AcpSessionUpdate]s via [emit] as work
  /// progresses; the returned stop reason ends the turn.
  ///
  /// [isCancelled] flips to true when the client sends `session/cancel`;
  /// check it between steps and return [AcpStopReason.cancelled].
  Future<AcpStopReason> prompt(
    AcpPromptRequest request, {
    required void Function(AcpSessionUpdate update) emit,
    required bool Function() isCancelled,
  });

  /// Requests user permission for a tool call. Returns the outcome.
  ///
  /// Default implementations of servers wire this to
  /// `session/request_permission`; backends that never need permission can
  /// return [AcpPermissionOutcome.allow] immediately.
  Future<AcpPermissionOutcome> requestPermission(AcpPermissionRequest request);

  /// Cancels all in-flight work for a session (best effort).
  void cancelSession(String sessionId) {}

  /// Releases session resources.
  Future<void> disposeSession(String sessionId) async {}
}
