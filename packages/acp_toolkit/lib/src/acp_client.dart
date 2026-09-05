import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import 'acp_types.dart';

/// Result of a successful `initialize` handshake.
final class AcpAgentInfo {
  const AcpAgentInfo({
    required this.protocolVersion,
    required this.name,
    required this.version,
    required this.capabilities,
  });

  factory AcpAgentInfo.fromResult(Map<String, Object?> result) {
    final info = jsonDecodeMap(result['agentInfo']);
    return AcpAgentInfo(
      protocolVersion: result['protocolVersion'] as int? ?? 1,
      name: info['name'] as String? ?? '',
      version: info['version'] as String? ?? '',
      capabilities: jsonDecodeMap(result['agentCapabilities']),
    );
  }

  final int protocolVersion;
  final String name;
  final String version;
  final Map<String, Object?> capabilities;
}

/// Result of a completed prompt turn.
final class AcpPromptTurnResult {
  const AcpPromptTurnResult({required this.sessionId, required this.stopReason});

  final String sessionId;
  final AcpStopReason stopReason;
}

/// Handles server→client requests other than `session/request_permission`
/// (e.g. `fs/read_text_file`, `fs/write_text_file`, `terminal/*`) when the
/// client advertised those capabilities.
///
/// Return value becomes (or is merged into) the JSON-RPC `result`. Throw to
/// produce a JSON-RPC error response.
typedef AcpServerRequestHandler =
    Future<Map<String, Object?>?> Function(
      String method,
      Map<String, Object?> params,
    );

/// Decides tool-call permission on behalf of the user. Returning
/// [AcpPermissionOutcome.allow] answers with the first `allow_once` option,
/// [AcpPermissionOutcome.reject] with the first `reject_once`.
typedef AcpPermissionDelegate = Future<AcpPermissionOutcome> Function(
  AcpPermissionRequest request,
);

/// Callback for `session/update` notifications.
typedef AcpUpdateHandler = void Function(AcpSessionUpdate update);

/// ACP v1 client: drives an agent over JSON-RPC 2.0 newline-delimited
/// framing (the mirror image of [AcpStdioServer]).
///
/// Lifecycle:
/// ```dart
/// final client = await AcpClient.spawn(['claude-code-acp']);
/// await client.initialize();
/// final sessionId = await client.newSession(cwd: projectDir.path);
/// final turn = await client.prompt(sessionId, 'Fix the failing test',
///     onUpdate: (u) => print(u.sessionUpdate));
/// client.cancel(sessionId);
/// await client.dispose();
/// ```
///
/// Inbound requests are dispatched to [permissionHandler] and
/// [serverRequestHandler]; when no handler matches, the request is answered
/// with a JSON-RPC "method not found" error so agents can degrade
/// gracefully.
final class AcpClient {
  /// Connects to an already-running agent's streams.
  ///
  /// [agentOutput] is the agent's stdout; [agentInput] receives lines that
  /// are written to the agent's stdin.
  AcpClient({
    required Stream<List<int>> agentOutput,
    required StringSink agentInput,
    this.protocolVersion = 1,
    this.permissionHandler,
    this.serverRequestHandler,
    this.onOutOfTurnEvent,
    Process? process,
  }) : _agentInput = agentInput,
       _process = process {
    _subscription = agentOutput
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onDone: _onClosed);
  }

  /// Spawns [command] with [arguments] as an ACP agent subprocess.
  static Future<AcpClient> spawn(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    int protocolVersion = 1,
    AcpPermissionDelegate? permissionHandler,
    AcpServerRequestHandler? serverRequestHandler,
    AcpUpdateHandler? onOutOfTurnEvent,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    );
    return AcpClient(
      agentOutput: process.stdout,
      agentInput: process.stdin,
      protocolVersion: protocolVersion,
      permissionHandler: permissionHandler,
      serverRequestHandler: serverRequestHandler,
      onOutOfTurnEvent: onOutOfTurnEvent,
      process: process,
    );
  }

  /// Highest protocol version this client supports; negotiated down when the
  /// agent only speaks an older one.
  final int protocolVersion;

  /// Called when the agent sends `session/request_permission`. When null,
  /// permission requests are answered as rejected (safe default).
  final AcpPermissionDelegate? permissionHandler;

  /// Called for any other server→client request. When null (or when it
  /// throws [UnimplementedError]), the request is answered with a
  /// method-not-found error.
  final AcpServerRequestHandler? serverRequestHandler;

  /// Receives `session/update` notifications arriving outside any active
  /// [prompt] turn (e.g. agent-initiated progress after cancellation).
  final AcpUpdateHandler? onOutOfTurnEvent;

  final StringSink _agentInput;
  final Process? _process;
  StreamSubscription<void>? _subscription;
  final Map<Object, Completer<Map<String, Object?>>> _pending = {};
  final Map<String, AcpUpdateHandler> _activePrompts = {};
  var _nextRequestId = 1;
  var _initialized = false;
  var _closed = false;

  bool get isClosed => _closed;

  Future<void> initialize() async {
    final result = await _request('initialize', {
      'protocolVersion': protocolVersion,
      'clientCapabilities': const <String, Object?>{},
    });
    final agreed = result['protocolVersion'] as int? ?? protocolVersion;
    if (agreed > protocolVersion) {
      throw StateError(
        'Agent requires ACP v$agreed but this client supports v$protocolVersion',
      );
    }
    _initialized = true;
  }

  Future<String> newSession({String cwd = '.'}) async {
    _ensureInitialized();
    final result = await _request('session/new', {'cwd': cwd});
    final sessionId = result['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Agent returned no sessionId from session/new');
    }
    return sessionId;
  }

  /// Runs one prompt turn, streaming [AcpSessionUpdate]s to [onUpdate].
  Future<AcpPromptTurnResult> prompt(
    String sessionId,
    List<AcpContentBlock> content, {
    AcpUpdateHandler? onUpdate,
  }) async {
    _ensureInitialized();
    final handler = onUpdate;
    if (handler != null) {
      _activePrompts[sessionId] = handler;
    }
    try {
      final result = await _request('session/prompt', {
        'sessionId': sessionId,
        'prompt': content.map((c) => c.toJson()).toList(),
      });
      return AcpPromptTurnResult(
        sessionId: sessionId,
        stopReason: AcpStopReason.fromWire(
          result['stopReason'] as String? ?? 'end_turn',
        ),
      );
    } finally {
      if (handler != null && identical(_activePrompts[sessionId], handler)) {
        _activePrompts.remove(sessionId);
      }
    }
  }

  /// Convenience for text-only prompts.
  Future<AcpPromptTurnResult> promptText(
    String sessionId,
    String text, {
    AcpUpdateHandler? onUpdate,
  }) => prompt(sessionId, [AcpTextBlock(text)], onUpdate: onUpdate);

  /// Cancels in-flight work for [sessionId] (notification; fire and forget).
  void cancel(String sessionId) {
    _write({
      'jsonrpc': '2.0',
      'method': 'session/cancel',
      'params': {'sessionId': sessionId},
    });
  }

  /// Kills the agent process (when owned) and stops listening.
  Future<void> dispose() async {
    _closed = true;
    await _subscription?.cancel();
    for (final completer in _pending.values) {
      completer.completeError(StateError('ACP client disposed'));
    }
    _pending.clear();
    _process?.kill();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError("Client not initialized: call 'initialize' first");
    }
    if (_closed) {
      throw StateError('ACP client is closed');
    }
  }

  Future<Map<String, Object?>> _request(
    String method,
    Map<String, Object?> params,
  ) {
    final id = _nextRequestId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _write({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    return completer.future;
  }

  Future<void> _onLine(String line) async {
    if (_closed || line.trim().isEmpty) return;
    Map<String, Object?> message;
    try {
      message = jsonDecodeMap(line);
    } on Object {
      return; // Malformed line from the agent; ignore rather than crash.
    }

    final method = message['method'] as String?;
    final id = message['id'];

    // Response to one of our requests.
    if (method == null && id != null) {
      final pending = _pending.remove(id);
      if (pending == null) return;
      final error = message['error'];
      if (error != null) {
        pending.completeError(StateError('$error'));
      } else {
        pending.complete(jsonDecodeMap(message['result']));
      }
      return;
    }

    // Server→client request.
    if (method != null && id != null) {
      await _handleRequest(id, method, jsonDecodeMap(message['params']));
      return;
    }

    // Notification.
    if (method == 'session/update') {
      final params = jsonDecodeMap(message['params']);
      final sessionId = params['sessionId'] as String? ?? '';
      final update = AcpSessionUpdate.fromJson(jsonDecodeMap(params['update']));
      final handler = _activePrompts[sessionId] ?? onOutOfTurnEvent;
      handler?.call(update);
    }
  }

  Future<void> _handleRequest(
    Object id,
    String method,
    Map<String, Object?> params,
  ) async {
    try {
      switch (method) {
        case 'session/request_permission':
          final outcome = await _resolvePermission(params);
          _respond(id, {'outcome': outcome});
        default:
          final handler = serverRequestHandler;
          if (handler == null) {
            throw UnimplementedError();
          }
          final result = await handler(method, params);
          _respond(id, result ?? <String, Object?>{});
      }
    } on UnimplementedError {
      _respondError(id, -32601, 'Method not supported by client: $method');
    } on Object catch (error) {
      _respondError(id, -32603, '$error');
    }
  }

  Future<Map<String, Object?>> _resolvePermission(
    Map<String, Object?> params,
  ) async {
    final options =
        (params['options'] as List<Object?>? ?? [])
            .whereType<Map<String, Object?>>()
            .toList();
    Map<String, Object?> fallbackOption() {
      final reject = options.firstWhere(
        (o) => (o['kind'] as String?)?.startsWith('reject') == true,
        orElse: () => const <String, Object?>{},
      );
      return reject.isNotEmpty ? Map<String, Object?>.from(reject) : {};
    }

    final delegate = permissionHandler;
    if (delegate == null) {
      return {'outcome': 'rejected', 'optionId': fallbackOption()['optionId']};
    }
    final meta = jsonDecodeMap(params['_meta']);
    final request = AcpPermissionRequest(
      sessionId: params['sessionId'] as String? ?? '',
      toolCallId: params['toolCallId'] as String? ?? '',
      title: meta['title'] as String? ?? '',
      kind: meta['kind'] as String? ?? 'other',
    );
    final outcome = await delegate(request);
    final wantedKind = switch (outcome) {
      AcpPermissionOutcome.allow => 'allow',
      AcpPermissionOutcome.reject => 'reject',
      AcpPermissionOutcome.cancelled => 'cancel',
    };
    final option = options.firstWhere(
      (o) => (o['kind'] as String?)?.startsWith(wantedKind) == true,
      orElse: () =>
          wantedKind == 'allow'
          ? const <String, Object?>{'optionId': 'allow'}
          : fallbackOption(),
    );
    return {
      'outcome': switch (outcome) {
        AcpPermissionOutcome.allow => 'selected',
        AcpPermissionOutcome.reject => 'selected',
        AcpPermissionOutcome.cancelled => 'cancelled',
      },
      'optionId': option['optionId'],
    };
  }

  void _respond(Object id, Map<String, Object?> result) {
    _write({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void _respondError(Object id, int code, String message) {
    _write({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    });
  }

  void _onClosed() {
    _closed = true;
    for (final completer in _pending.values) {
      completer.completeError(StateError('Agent closed its output stream'));
    }
    _pending.clear();
  }

  void _write(Map<String, Object?> message) {
    _agentInput.writeln(jsonEncode(message));
  }
}
