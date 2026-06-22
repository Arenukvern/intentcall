import 'dart:math';

import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'json_helpers.dart';
import 'session_connector.dart';
import 'session_requests.dart';
import 'state_lock_manager.dart';
import 'state_store.dart';

final class IntentSessionManager {
  IntentSessionManager({required this.connector, required this.stateStore});

  final IntentSessionConnector connector;
  final StateStore stateStore;

  PersistedState _state = const PersistedState();

  PersistedState get state => _state;

  Future<void> load() async {
    _state = await stateStore.read();
  }

  SessionState? getSession(final String? sessionId) {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return null;
    }
    return _state.sessions[resolvedId];
  }

  String? get stickyEndpoint =>
      _state.activeSession?.endpoint ?? _state.stickyEndpoint;

  Future<AgentResult> startSession(
    final IntentSessionStartRequest request,
  ) async {
    try {
      final connectionData = await connector.connect(
        mode: request.mode,
        targetId: request.targetId,
        uri: request.uri,
        host: request.host,
        port: request.port,
        forceReconnect: request.forceReconnect,
      );

      final endpoint = connector.activeEndpointDisplay;
      if (endpoint == null || endpoint.isEmpty) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.connectFailed,
          message: 'Failed to resolve active endpoint after session start',
        );
      }

      final id = request.sessionId ?? _newSessionId();

      return await _withLockedResult(() async {
        final current = await stateStore.readUnlocked();
        final now = DateTime.now().toUtc();
        final nextSession = SessionState(
          id: id,
          endpoint: endpoint,
          createdAt: now,
          lastUsedAt: now,
          mode: request.mode.name,
          host: request.host,
          port: request.port,
          uri: request.uri,
        );

        final nextSessions = <String, SessionState>{
          ...current.sessions,
          id: nextSession,
        };

        final nextState = current.copyWith(
          activeSessionId: id,
          sessions: nextSessions,
          stickyEndpoint: endpoint,
          lastMode: request.mode.name,
        );

        await stateStore.writeUnlocked(nextState);
        _state = nextState;

        return AgentResult.success(
          data: {
            'sessionId': id,
            'endpoint': endpoint,
            'mode': request.mode.name,
            'connected': true,
            'reusedConnection': connectionData['reusedConnection'] == true,
            'selectionDiagnostics': connector.lastSelectionDiagnostics,
          },
        );
      });
    } on IntentSessionConnectionException catch (e) {
      if (e.reasonName ==
          IntentSessionConnectionFailureReason.multipleTargets) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.connectionSelectionRequired,
          message: e.message,
          details: _detailsMap(e.details),
        );
      }

      return AgentResult.failure(
        code: IntentSessionErrorCode.connectFailed,
        message: 'Failed to start session: ${e.message}',
        details: _detailsMap(e.details),
      );
    } on Exception catch (e) {
      return AgentResult.failure(
        code: IntentSessionErrorCode.connectFailed,
        message: 'Failed to start session: $e',
      );
    }
  }

  Future<AgentResult> attachSession([
    final IntentSessionAttachRequest request =
        const IntentSessionAttachRequest(),
  ]) async {
    final resolvedSession = await _withLockedResult(() async {
      final current = await stateStore.readUnlocked();
      _state = current;

      final resolvedId = _resolveSessionId(request.sessionId);
      if (resolvedId == null || resolvedId.isEmpty) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': request.sessionId},
        );
      }

      final session = current.sessions[resolvedId];
      if (session == null) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': request.sessionId},
        );
      }

      return AgentResult.success(data: {'session': session.toJson()});
    });

    if (!resolvedSession.ok) {
      return resolvedSession;
    }

    final sessionJson = resolvedSession.data['session'];
    final session = SessionState.fromJson(
      (sessionJson! as Map).cast<String, Object?>(),
    );

    try {
      final data = await connector.connect(
        mode: IntentSessionConnectionMode.uri,
        uri: session.endpoint,
        forceReconnect: request.forceReconnect,
      );

      return await _withLockedResult(() async {
        await _markSessionUsedLocked(
          session.id,
          endpointOverride: session.endpoint,
        );

        return AgentResult.success(data: {'sessionId': session.id, ...data});
      });
    } on Exception catch (e) {
      return AgentResult.failure(
        code: IntentSessionErrorCode.connectFailed,
        message: 'Failed to attach session ${session.id}: $e',
        details: {'sessionId': session.id},
      );
    }
  }

  Future<AgentResult> endSession(final String? sessionId) async {
    bool shouldDisconnect = false;

    final result = await _withLockedResult(() async {
      final current = await stateStore.readUnlocked();
      _state = current;

      final resolvedId = _resolveSessionId(sessionId);
      if (resolvedId == null || resolvedId.isEmpty) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': sessionId},
        );
      }

      final existing = current.sessions[resolvedId];
      if (existing == null) {
        return AgentResult.failure(
          code: IntentSessionErrorCode.sessionNotFound,
          message: 'Session not found',
          details: {'requestedSessionId': resolvedId},
        );
      }

      shouldDisconnect = current.activeSessionId == resolvedId;

      final nextSessions = <String, SessionState>{...current.sessions}
        ..remove(resolvedId);

      final nextActive = current.activeSessionId == resolvedId
          ? null
          : current.activeSessionId;

      final sticky = nextActive == null
          ? (nextSessions.values.isEmpty
                ? current.stickyEndpoint
                : nextSessions.values.last.endpoint)
          : current.stickyEndpoint;

      final nextState = current.copyWith(
        sessions: nextSessions,
        activeSessionId: nextActive,
        clearActiveSessionId: nextActive == null,
        stickyEndpoint: sticky,
        clearStickyEndpoint: sticky == null || sticky.isEmpty,
      );

      await stateStore.writeUnlocked(nextState);
      _state = nextState;

      return AgentResult.success(
        data: {
          'sessionId': resolvedId,
          'ended': true,
          'activeSessionId': nextState.activeSessionId,
          'remainingSessions': nextState.sessions.length,
        },
      );
    });

    if (result.ok && shouldDisconnect) {
      await connector.disconnect();
    }

    return result;
  }

  Future<void> markSessionUsed(
    final String? sessionId, {
    final String? endpointOverride,
  }) async {
    final resolvedId = _resolveSessionId(sessionId);
    if (resolvedId == null || resolvedId.isEmpty) {
      return;
    }

    await _withLockedResult(() async {
      await _markSessionUsedLocked(
        resolvedId,
        endpointOverride: endpointOverride,
      );
      return AgentResult.success();
    });
  }

  String? _resolveSessionId(final String? sessionId) {
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }
    return _state.activeSessionId;
  }

  Future<void> _markSessionUsedLocked(
    final String resolvedSessionId, {
    final String? endpointOverride,
  }) async {
    final current = await stateStore.readUnlocked();
    final existing = current.sessions[resolvedSessionId];
    if (existing == null) {
      _state = current;
      return;
    }

    final endpoint = endpointOverride ?? existing.endpoint;
    final next = existing.copyWith(
      lastUsedAt: DateTime.now().toUtc(),
      endpoint: endpoint,
    );

    final nextSessions = <String, SessionState>{
      ...current.sessions,
      resolvedSessionId: next,
    };

    final nextState = current.copyWith(
      sessions: nextSessions,
      activeSessionId: resolvedSessionId,
      stickyEndpoint: endpoint,
      lastMode: existing.mode,
    );

    await stateStore.writeUnlocked(nextState);
    _state = nextState;
  }

  Future<AgentResult> _withLockedResult(
    final Future<AgentResult> Function() action,
  ) async {
    try {
      return await stateStore.withStateLock(action);
    } on StateLockException catch (e) {
      return AgentResult.failure(
        code: IntentSessionErrorCode.stateLockTimeout,
        message: e.message,
        details: {'lockFilePath': e.lockFilePath, 'owner': e.owner},
      );
    } on Exception catch (e) {
      return AgentResult.failure(
        code: IntentSessionErrorCode.stateStoreWriteFailed,
        message: 'State operation failed: $e',
      );
    }
  }

  String _newSessionId() {
    final rand = Random();
    final suffix = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 's_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  Map<String, Object?> _detailsMap(final Object? value) {
    if (value is Map) {
      return jsonObjectOrEmpty(value);
    }
    if (value == null) {
      return const <String, Object?>{};
    }
    final decoded = jsonObjectOrEmpty(value);
    if (decoded.isNotEmpty) {
      return decoded;
    }
    return {'details': jsonDecodeString(value)};
  }
}
