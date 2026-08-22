import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import 'acp_agent_backend.dart';
import 'acp_types.dart';

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
      await _handleMessage(message);
    }
  }

  Future<void> _handleMessage(Map<String, Object?> message) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params = message['params'];

    // Responses to our own calls (e.g. session/request_permission).
    if (method == null && id != null) {
      final pending = _pendingPermissions.remove(id);
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
    final requestId = _nextRequestId++;
    final responseCompleter = Completer<Map<String, Object?>>();
    _pendingPermissions[requestId] = responseCompleter;
    _write({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'session/request_permission',
      'params': request.toParams(),
    });
    try {
      final response = await responseCompleter.future.timeout(
        const Duration(minutes: 5),
      );
      final outcome = response['outcome'] as Map<String, Object?>?;
      final optionId = outcome?['optionId'] as String?;
      return switch (optionId) {
        'allow' => AcpPermissionOutcome.allow,
        'reject' => AcpPermissionOutcome.reject,
        _ => AcpPermissionOutcome.cancelled,
      };
    } on TimeoutException {
      return AcpPermissionOutcome.cancelled;
    } finally {
      _pendingPermissions.remove(requestId);
    }
  }

  final Map<int, Completer<Map<String, Object?>>> _pendingPermissions = {};

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
