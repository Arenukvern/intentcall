// Copyright (c) 2025, IntentCall authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:path/path.dart' as p;

import 'json_helpers.dart';
import 'safe_writes.dart';
import 'state_lock_manager.dart';

final class SessionState {
  const SessionState({
    required this.id,
    required this.endpoint,
    required this.createdAt,
    required this.lastUsedAt,
    required this.mode,
    this.host,
    this.port,
    this.uri,
  });

  factory SessionState.fromJson(final Map<String, Object?> json) {
    final mode = jsonDecodeString(json['mode']);
    return SessionState(
      id: jsonDecodeString(json['id']),
      endpoint: jsonDecodeString(json['endpoint']),
      createdAt:
          DateTime.tryParse(jsonDecodeString(json['createdAt']))?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastUsedAt:
          DateTime.tryParse(jsonDecodeString(json['lastUsedAt']))?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      mode: mode.isEmpty ? 'auto' : mode,
      host: _optionalJsonString(json['host']),
      port: jsonDecodeNullableInt(json['port']),
      uri: _optionalJsonString(json['uri']),
    );
  }

  final String id;
  final String endpoint;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String mode;
  final String? host;
  final int? port;
  final String? uri;

  SessionState copyWith({final DateTime? lastUsedAt, final String? endpoint}) =>
      SessionState(
        id: id,
        endpoint: endpoint ?? this.endpoint,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        mode: mode,
        host: host,
        port: port,
        uri: uri,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'endpoint': endpoint,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
    'mode': mode,
    'host': host,
    'port': port,
    'uri': uri,
  };
}

final class PersistedState {
  const PersistedState({
    this.schemaVersion = 1,
    this.activeSessionId,
    this.sessions = const <String, SessionState>{},
    this.stickyEndpoint,
    this.lastMode,
  });

  factory PersistedState.fromJson(final Map<String, Object?> json) {
    final rawSessions = jsonObjectOrEmpty(json['sessions']);
    final sessions = <String, SessionState>{};
    for (final entry in rawSessions.entries) {
      final key = jsonDecodeString(entry.key);
      final value = entry.value;
      if (value is Map || verifyMapDecodability(value)) {
        sessions[key] = SessionState.fromJson(jsonObjectOrEmpty(value));
      }
    }

    return PersistedState(
      schemaVersion: jsonDecodeNullableInt(json['schemaVersion']) ?? 1,
      activeSessionId: _optionalJsonString(json['activeSessionId']),
      stickyEndpoint: _optionalJsonString(json['stickyEndpoint']),
      lastMode: _optionalJsonString(json['lastMode']),
      sessions: sessions,
    );
  }

  final int schemaVersion;
  final String? activeSessionId;
  final Map<String, SessionState> sessions;
  final String? stickyEndpoint;
  final String? lastMode;

  SessionState? get activeSession {
    final id = activeSessionId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return sessions[id];
  }

  PersistedState copyWith({
    final int? schemaVersion,
    final String? activeSessionId,
    final bool clearActiveSessionId = false,
    final Map<String, SessionState>? sessions,
    final String? stickyEndpoint,
    final bool clearStickyEndpoint = false,
    final String? lastMode,
    final bool clearLastMode = false,
  }) => PersistedState(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    activeSessionId: clearActiveSessionId
        ? null
        : (activeSessionId ?? this.activeSessionId),
    sessions: sessions ?? this.sessions,
    stickyEndpoint: clearStickyEndpoint
        ? null
        : (stickyEndpoint ?? this.stickyEndpoint),
    lastMode: clearLastMode ? null : (lastMode ?? this.lastMode),
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'activeSessionId': activeSessionId,
    'stickyEndpoint': stickyEndpoint,
    'lastMode': lastMode,
    'sessions': sessions.map(
      (final key, final value) => MapEntry(key, value.toJson()),
    ),
  };
}

final class StateStore {
  StateStore({required this.path, final StateLockManager? lockManager})
    : lockManager =
          lockManager ??
          StateLockManager(
            lockFilePath: p.normalize(p.join(p.dirname(path), 'state.lock')),
          );

  final String path;
  final StateLockManager lockManager;

  Future<T> withStateLock<T>(final Future<T> Function() action) =>
      lockManager.withLock(action);

  Future<PersistedState> read() => withStateLock(readUnlocked);

  Future<void> write(final PersistedState state) =>
      withStateLock(() => writeUnlocked(state));

  Future<PersistedState> readUnlocked() async {
    try {
      final file = io.File(path);
      if (!file.existsSync()) {
        return const PersistedState();
      }

      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) {
        return const PersistedState();
      }

      return PersistedState.fromJson(jsonObjectOrEmpty(raw));
    } on Exception {
      return const PersistedState();
    }
  }

  Future<void> writeUnlocked(final PersistedState state) async {
    final file = io.File(path);
    final payload = const JsonEncoder.withIndent('  ').convert(state.toJson());
    await SafeFileWriter.writeTextFile(path: file.path, content: payload);

    if (!io.Platform.isWindows) {
      io.Process.runSync('chmod', ['600', p.normalize(file.path)]);
    }
  }
}

String? _optionalJsonString(final Object? value) {
  if (value == null) {
    return null;
  }
  return jsonDecodeString(value);
}
