import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import 'acp_agent_backend.dart';
import 'acp_move.dart';
import 'acp_types.dart';

/// Optional capability for backends that need to ask the CLIENT for
/// permission mid-turn (e.g. file-write approval). The server attaches
/// itself at startup when the backend implements this interface; the
/// attached requester sends `session/request_permission` to the client and
/// awaits its outcome.
abstract interface class AcpPermissionRequesting {
  /// Called once by the server before the first message is dispatched.
  void attachPermissionRequester(
    Future<AcpPermissionOutcome> Function(AcpPermissionRequest request)
    requester,
  );
}

/// ACP v1 server: JSON-RPC 2.0 over stdio (newline-delimited).
///
/// Implements the baseline agent surface:
/// - `initialize` → protocol version + capability negotiation
/// - `session/new` → [AcpAgentBackend.createSession]
/// - `session/prompt` → [AcpAgentBackend.prompt], streaming
///   `session/update` notifications back to the client
/// - `session/cancel` (notification) → cancels in-flight work
///
/// Client-side callbacks the backend may trigger:
/// - `session/request_permission` → [AcpAgentBackend.requestPermission]
final class AcpStdioServer {
  AcpStdioServer({
    required this.backend,
    this.protocolVersion = 1,
    Stream<List<int>>? inputStream,
    StringSink? outputSink,
  }) : input = inputStream ?? stdin,
       output = outputSink ?? stdout;

  final AcpAgentBackend backend;
  final Stream<List<int>> input;
  final StringSink output;

  /// Highest protocol version this server supports. Negotiated down to the
  /// client's version when lower.
  final int protocolVersion;

  static const String serverName = 'acp-server';

  final Map<String, String> _sessionCwds = {};
  final Map<String, bool Function()> _cancelFlags = {};
  int _nextRequestId = 1;
  bool _initialized = false;

  Future<void> run() async {
    if (backend is AcpPermissionRequesting) {
      (backend as AcpPermissionRequesting)
          .attachPermissionRequester(requestPermissionFromClient);
    }
    // R7 production #4: the remote mover — the client is the session
    // actor's brain; every decision round-trips as session/propose_move.
    if (backend is AcpMoveProposing) {
      (backend as AcpMoveProposing).attachMoveProposer(proposeMoveFromClient);
    }
    final lines = input.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Map<String, Object?> message;
      try {
        message = jsonDecodeMap(line);
      } on Object catch (error) {
        _write({
          'jsonrpc': '2.0',
          'id': null,
          'error': _error(-32700, 'Parse error: $error'),
        });
        continue;
      }
      // Responses to OUR OWN calls (session/request_permission,
      // session/propose_move) must be routed out-of-band: while a prompt
      // turn is in flight, the loop is blocked inside `backend.prompt` — a
      // response awaited by that very turn would otherwise deadlock the
      // stream (measured: permission round-trip test hung until this
      // out-of-band route existed).
      final method = message['method'] as String?;
      final id = message['id'];
      if (method == null && id != null) {
        final pending = _pendingClientRequests.remove(id);
        if (pending != null) {
          if (message['error'] != null) {
            pending.completeError(StateError('${message['error']}'));
          } else {
            pending.complete(jsonDecodeMap(message['result']));
          }
          continue;
        }
      }
      // Dispatch CONCURRENTLY (ACP-faithful): a prompt turn streams updates
      // for a long time, and while it is in flight the stream must still
      // deliver `session/cancel` and permission responses. Awaiting the
      // dispatch inline deadlocked exactly those round-trips (measured: the
      // permission round-trip hung until dispatch went concurrent).
      unawaited(_handleMessageSafe(message));
    }
  }

  Future<void> _handleMessageSafe(Map<String, Object?> message) async {
    try {
      await _handleMessage(message);
    } on Object catch (error, stack) {
      _write({
        'jsonrpc': '2.0',
        'id': message['id'],
        'error': _error(-32603, '$error', data: {'stack': '$stack'}),
      });
    }
  }

  Future<void> _handleMessage(Map<String, Object?> message) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params = message['params'];

    // Responses to our own calls (session/request_permission,
    // session/propose_move).
    if (method == null && id != null) {
      final pending = _pendingClientRequests.remove(id);
      if (pending != null) {
        if (message['error'] != null) {
          pending.completeError(StateError('${message['error']}'));
        } else {
          pending.complete(jsonDecodeMap(message['result']));
        }
      }
      return;
    }

    // Notifications carry no id.
    if (id == null) {
      if (method == 'session/cancel') {
        final p = jsonDecodeMap(params);
        final sessionId = p['sessionId'] as String? ?? '';
        _cancelFlags[sessionId]?.call();
        backend.cancelSession(sessionId);
      }
      return;
    }

    if (!_initialized && method != 'initialize') {
      _write({
        'jsonrpc': '2.0',
        'id': id,
        'error': _error(
          -32002,
          "Server not initialized: expected 'initialize'",
        ),
      });
      return;
    }

    try {
      final result = await _dispatch(method, jsonDecodeMap(params), id);
      if (result != _noResponse) {
        _write({'jsonrpc': '2.0', 'id': id, 'result': result});
      }
    } on Object catch (error, stack) {
      _write({
        'jsonrpc': '2.0',
        'id': id,
        'error': _error(-32603, '$error', data: {'stack': '$stack'}),
      });
    }
  }

  /// Sentinel for notifications that produce no response.
  static const Object _noResponse = Object();

  Future<Object?> _dispatch(
    String? method,
    Map<String, Object?> params,
    Object? id,
  ) async {
    switch (method) {
      case 'initialize':
        return _initialize(params);

      case 'session/new':
        final request = AcpSessionNewRequest.fromJson(params);
        final sessionId = await backend.createSession(request);
        _sessionCwds[sessionId] = request.cwd;
        return {'sessionId': sessionId};

      case 'session/prompt':
        return _prompt(params);

      case 'ping':
        return <String, Object?>{};

      default:
        throw StateError('Method not found: $method');
    }
  }

  Map<String, Object?> _initialize(Map<String, Object?> params) {
    _initialized = true;
    final clientVersion = params['protocolVersion'] as int? ?? protocolVersion;
    final agreedVersion = clientVersion < protocolVersion
        ? clientVersion
        : protocolVersion;
    return {
      'protocolVersion': agreedVersion,
      'agentCapabilities': backend.agentCapabilities,
      'agentInfo': {'name': backend.name, 'version': backend.version},
      'authMethods': [],
    };
  }

  Future<Map<String, Object?>> _prompt(Map<String, Object?> params) async {
    final request = AcpPromptRequest.fromJson(params);
    if (request.sessionId.isEmpty ||
        !_sessionCwds.containsKey(request.sessionId)) {
      throw StateError('Unknown session: ${request.sessionId}');
    }

    var cancelled = false;
    _cancelFlags[request.sessionId] = () => cancelled = true;

    try {
      final stopReason = await backend.prompt(
        request,
        emit: (update) =>
            _notify('session/update', update.toJson(request.sessionId)),
        isCancelled: () => cancelled,
      );
      return {'stopReason': stopReason.wire};
    } finally {
      _cancelFlags.remove(request.sessionId);
    }
  }

  /// Sends a `session/request_permission` call to the client and awaits its
  /// response. Exposed for backends via [AcpAgentBackend.requestPermission]
  /// wiring.
  Future<AcpPermissionOutcome> requestPermissionFromClient(
    AcpPermissionRequest request,
  ) async {
    final response = await _callClient(
      'session/request_permission',
      request.toParams(),
    );
    final outcome = response['outcome'] as Map<String, Object?>?;
    final optionId = outcome?['optionId'] as String?;
    return switch (optionId) {
      'allow' => AcpPermissionOutcome.allow,
      'reject' => AcpPermissionOutcome.reject,
      _ => AcpPermissionOutcome.cancelled,
    };
  }

  /// R7 production #4 — sends a `session/propose_move` call to the client
  /// and awaits its typed tool calls (the remote mover round-trip). A
  /// client that never answers (timeout) yields an EMPTY response — the
  /// loop closes the decision; the goal gate grades the end state. The
  /// answer's `decisionId` must match (a stale/mismatched reply is
  /// treated as an empty move, never applied to another decision).
  Future<AcpMoveResponse> proposeMoveFromClient(
    AcpMoveProposal proposal,
  ) async {
    try {
      final response = await _callClient(
        'session/propose_move',
        proposal.toParams(),
      );
      final echoed = response['decisionId'] as String?;
      if (echoed != null && echoed != proposal.decisionId) {
        // Stale/mismatched reply: never applied to another decision.
        return const AcpMoveResponse();
      }
      return AcpMoveResponse.fromJson(response);
    } on TimeoutException {
      return const AcpMoveResponse();
    }
  }

  /// One server→client JSON-RPC call + response await (the shared
  /// request_permission / propose_move round-trip machinery).
  Future<Map<String, Object?>> _callClient(
    String method,
    Map<String, Object?> params,
  ) async {
    final requestId = _nextRequestId++;
    final responseCompleter = Completer<Map<String, Object?>>();
    _pendingClientRequests[requestId] = responseCompleter;
    _write({'jsonrpc': '2.0', 'id': requestId, 'method': method,
        'params': params});
    try {
      return await responseCompleter.future.timeout(
        const Duration(minutes: 5),
      );
    } finally {
      _pendingClientRequests.remove(requestId);
    }
  }

  final Map<int, Completer<Map<String, Object?>>> _pendingClientRequests =
      {};

  void _notify(String method, Map<String, Object?> params) {
    _write({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  void _write(Map<String, Object?> message) {
    output.writeln(jsonEncode(message));
  }

  Map<String, Object?> _error(
    int code,
    String message, {
    Map<String, Object?>? data,
  }) => {'code': code, 'message': message, 'data': ?data};
}
