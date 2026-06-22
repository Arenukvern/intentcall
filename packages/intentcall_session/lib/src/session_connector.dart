import 'session_requests.dart';

abstract final class IntentSessionConnectionFailureReason {
  static const multipleTargets = 'multipleTargets';
  static const targetNotFound = 'targetNotFound';
  static const noTargets = 'noTargets';
  static const invalidUri = 'invalidUri';
  static const invalidTargetId = 'invalidTargetId';
}

/// Runtime-specific connection failure surfaced to the session manager.
abstract interface class IntentSessionConnectionException implements Exception {
  String get reasonName;

  String get message;

  Object? get details;
}

/// The only runtime-specific operation required by IntentCall sessions.
abstract interface class IntentSessionConnector {
  String? get activeEndpointDisplay;

  Map<String, Object?> get lastSelectionDiagnostics;

  Future<Map<String, Object?>> connect({
    final IntentSessionConnectionMode mode = IntentSessionConnectionMode.auto,
    final String? targetId,
    final String? uri,
    final String? host,
    final int? port,
    final bool forceReconnect = false,
  });

  Future<void> disconnect();
}
