import 'package:meta/meta.dart';

/// Connection mode requested by a session start or attach operation.
enum IntentSessionConnectionMode { auto, manual, uri }

/// Stable error codes returned by intent session APIs.
abstract final class IntentSessionErrorCode {
  static const connectFailed = 'connect_failed';
  static const connectionSelectionRequired = 'connection_selection_required';
  static const sessionNotFound = 'session_not_found';
  static const stateLockTimeout = 'state_lock_timeout';
  static const stateStoreWriteFailed = 'state_store_write_failed';
}

/// Starts or replaces the active runtime session.
@immutable
final class IntentSessionStartRequest {
  const IntentSessionStartRequest({
    this.mode = IntentSessionConnectionMode.auto,
    this.targetId,
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
    this.sessionId,
  });

  final IntentSessionConnectionMode mode;
  final String? targetId;
  final String? uri;
  final String? host;
  final int? port;
  final bool forceReconnect;
  final String? sessionId;
}

/// Attaches to an existing runtime session.
@immutable
final class IntentSessionAttachRequest {
  const IntentSessionAttachRequest({
    this.sessionId,
    this.forceReconnect = false,
  });

  final String? sessionId;
  final bool forceReconnect;
}
