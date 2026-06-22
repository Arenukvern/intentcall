import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'session_manager.dart';
import 'session_requests.dart';

/// Invokes IntentCall registry entries after resolving an optional session.
final class IntentSessionExecutor {
  const IntentSessionExecutor({required this.sessions, required this.registry});

  final IntentSessionManager sessions;
  final AgentRegistry registry;

  Future<AgentResult> invoke({
    required final String qualifiedName,
    final AgentArguments arguments = const <String, Object?>{},
    final String? sessionId,
    final String? correlationId,
    final bool forceReconnect = false,
  }) async {
    final attach = await sessions.attachSession(
      IntentSessionAttachRequest(
        sessionId: sessionId,
        forceReconnect: forceReconnect,
      ),
    );
    if (!attach.ok) {
      return attach;
    }

    final result = await registry.invoke(
      qualifiedName,
      arguments,
      correlationId: correlationId,
    );

    if (result.ok) {
      await sessions.markSessionUsed(sessionId);
    }

    return result;
  }
}
