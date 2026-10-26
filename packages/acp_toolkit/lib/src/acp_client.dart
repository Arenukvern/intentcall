import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:from_json_to_json/from_json_to_json.dart';

import 'acp_auth.dart';
import 'acp_client_services.dart';
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
  const AcpPromptTurnResult({
    required this.sessionId,
    required this.stopReason,
  });

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
typedef AcpPermissionDelegate =
    Future<AcpPermissionOutcome> Function(AcpPermissionRequest request);

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
  /// [agentOutput] is the agent's stdout; [_agentInput] receives lines that
  /// are written to the agent's stdin.
  AcpClient({
    required Stream<List<int>> agentOutput,
    required this._agentInput,
    this.protocolVersion = 1,
    this.permissionHandler,
    this.serverRequestHandler,
    this.services,
    this.onTransportDispose,
    this.onOutOfTurnEvent,
    this.initializeSettleDelay = Duration.zero,
    this._process,
  }) {
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
    AcpClientServices? services,
    AcpUpdateHandler? onOutOfTurnEvent,
    void Function(String line)? onStderr,
    Duration initializeSettleDelay = Duration.zero,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    );
    // STDERR MUST BE DRAINED: a chatty agent (codex-acp dumps its model
    // catalog errors) fills the 64KB pipe buffer and blocks mid-startup,
    // so session/new never gets answered. Drain by default; surface
    // lines when [onStderr] is given.
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onStderr ?? (_) {});
    return AcpClient(
      agentOutput: process.stdout,
      agentInput: process.stdin,
      protocolVersion: protocolVersion,
      initializeSettleDelay: initializeSettleDelay,
      permissionHandler: permissionHandler,
      serverRequestHandler: serverRequestHandler,
      services: services,
      onOutOfTurnEvent: onOutOfTurnEvent,
      process: process,
    );
  }

  /// Highest protocol version this client supports; negotiated down when the
  /// agent only speaks an older one.
  final int protocolVersion;

  /// Settle pause between the initialize response and the `initialized`
  /// notification. Zero by default: the codex-acp session hang turned out
  /// to be its undrained stderr (fixed in [spawn]), not notification
  /// timing — the knob stays for agents that need it.
  final Duration initializeSettleDelay;

  /// The spawned agent process's pid, when this client owns one — for
  /// liveness observation only (never an unverified signal).
  int? get processPid => _process?.pid;

  /// Called when the agent sends `session/request_permission`. When null,
  /// permission requests are answered as rejected (safe default).
  final AcpPermissionDelegate? permissionHandler;

  /// Called for any other server→client request. When null (or when it
  /// throws [UnimplementedError]), the request is answered with a
  /// method-not-found error.
  final AcpServerRequestHandler? serverRequestHandler;

  /// Explicit owner-bound services; standard service methods never fall back
  /// to the generic extension handler.
  final AcpClientServices? services;

  /// Settles an externally owned transport before disposal completes.
  final Future<void> Function()? onTransportDispose;
  Future<void>? _disposal;

  /// Receives `session/update` notifications arriving outside any active
  /// [prompt] turn (e.g. agent-initiated progress after cancellation).
  final AcpUpdateHandler? onOutOfTurnEvent;

  final StringSink _agentInput;
  final Process? _process;
  StreamSubscription<void>? _subscription;
  final Map<Object, Completer<Map<String, Object?>>> _pending = {};
  final Map<String, AcpUpdateHandler> _activePrompts = {};
  final Map<String, AcpSessionModes> _sessionModes = {};
  var _nextRequestId = 1;
  var _initialized = false;
  var _closed = false;
  var _authMethods = <AcpAuthMethod>[];

  bool get isClosed => _closed;

  Future<void> initialize() async {
    final result = await _request('initialize', {
      'protocolVersion': protocolVersion,
      // Real agents validate the capability shape (gemini-cli rejects
      // `{}` with -32602) — spell the baseline honestly: no fs, no
      // terminal access.
      'clientCapabilities':
          services?.capabilities ??
          const <String, Object?>{
            'fs': <String, Object?>{
              'readTextFile': false,
              'writeTextFile': false,
            },
            'terminal': false,
          },
    });
    final agreed = result['protocolVersion'] as int? ?? protocolVersion;
    if (agreed > protocolVersion) {
      throw StateError(
        'Agent requires ACP v$agreed but this client supports v$protocolVersion',
      );
    }
    final rawMethods = result['authMethods'];
    if (rawMethods is List) {
      _authMethods = [
        for (final raw in rawMethods)
          if (raw is Map) AcpAuthMethod.fromJson(raw.cast<String, Object?>()),
      ];
    }
    _initialized = true;
    // ACP: the client MUST follow the initialize response with the
    // `initialized` notification. Sent inline: the codex-acp session hang
    // turned out to be its undrained stderr (drained in [spawn]), not
    // notification timing. A nonzero [initializeSettleDelay] (opt-in via
    // spawn for agents that need the gap) still creates a Timer — fake-async
    // tests pass Duration.zero precisely to avoid that.
    if (initializeSettleDelay > Duration.zero) {
      await Future<void>.delayed(initializeSettleDelay);
    }
    if (_closed) return;
    _write(const <String, Object?>{'jsonrpc': '2.0', 'method': 'initialized'});
  }

  /// Authentication methods the agent advertised at `initialize`
  /// (empty until initialize completes; most agents advertise none and
  /// manage credentials in their own config store).
  List<AcpAuthMethod> get authMethods => List.unmodifiable(_authMethods);

  /// Answers the agent's `auth_required` with the chosen [methodId]
  /// (ACP `session/authenticate`). Agents that complete OAuth over ACP
  /// (e.g. Gemini CLI) finish here; terminal-auth agents need their own
  /// login flow first — [AcpAuthRequiredException] names the state.
  Future<void> authenticate(final String methodId) async {
    _ensureInitialized();
    await _request('session/authenticate', {'methodId': methodId});
  }

  Future<String> newSession({
    String cwd = '.',
    List<Map<String, Object?>> mcpServers = const [],
  }) async {
    _ensureInitialized();
    final Map<String, Object?> result;
    try {
      // `mcpServers` is part of the v1 session/new contract — strict
      // agents (gemini-cli) reject its absence with -32602.
      result = await _request('session/new', {
        'cwd': cwd,
        'mcpServers': mcpServers,
      });
    } on AcpRemoteError catch (error) {
      // ACP: `session/new` may refuse with -32000/auth_required; surface
      // it typed with the advertised methods instead of a string error.
      if (error.code == -32000 || error.message.contains('auth')) {
        final data = error.data;
        final methods = <AcpAuthMethod>[
          if (data is Map && data['authMethods'] is List)
            for (final raw in data['authMethods'] as List)
              if (raw is Map)
                AcpAuthMethod.fromJson(raw.cast<String, Object?>()),
        ];
        throw AcpAuthRequiredException(
          message: error.message,
          authMethods: methods.isNotEmpty ? methods : _authMethods,
        );
      }
      rethrow;
    }
    final sessionId = result['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Agent returned no sessionId from session/new');
    }
    _rememberModes(sessionId, result['modes']);
    return sessionId;
  }

  /// The mode set advertised for [sessionId] (null when the agent does
  /// not implement modes — the coarse client-side switcher still works).
  AcpSessionModes? sessionModesOf(final String sessionId) =>
      _sessionModes[sessionId];

  /// Switches the agent's own mode (`session/set_mode`) — the codex/zed/
  /// cursor-style switcher's agent side. The cached current id follows.
  Future<void> setSessionMode(
    final String sessionId,
    final String modeId,
  ) async {
    _ensureInitialized();
    await _request('session/set_mode', {
      'sessionId': sessionId,
      'modeId': modeId,
    });
    final known = _sessionModes[sessionId];
    _sessionModes[sessionId] = AcpSessionModes(
      currentModeId: modeId,
      available: known?.available ?? const [],
    );
  }

  void _rememberModes(final String sessionId, final Object? raw) {
    if (raw is Map) {
      _sessionModes[sessionId] = AcpSessionModes.fromJson(
        raw.cast<String, Object?>(),
      );
    } else {
      _sessionModes.remove(sessionId);
    }
  }

  /// Resumes a previous conversation (`session/load`, ACP spec): the
  /// agent answers carrying the session id and replays its history as
  /// `session/update` notifications on the normal update channel — a
  /// resumed session prompts exactly like a fresh one. Agents that do
  /// not implement the method answer -32601 (method not found); callers
  /// fall back to [newSession] with their own "context reset" marker.
  ///
  /// This is the multiplayer-handoff enabler: a chat's session id lives
  /// on the shared document, so the device that takes over the session
  /// (or the restarted process on the same device) reloads the
  /// conversation instead of silently starting empty.
  Future<String> loadSession(
    String sessionId, {
    String cwd = '.',
    List<Map<String, Object?>> mcpServers = const [],
  }) async {
    _ensureInitialized();
    final Map<String, Object?> result;
    try {
      // The params mirror session/new's strictness (gemini-cli rejects
      // absent mcpServers with -32602).
      result = await _request('session/load', {
        'sessionId': sessionId,
        'cwd': cwd,
        'mcpServers': mcpServers,
      });
    } on AcpRemoteError catch (error) {
      // Same typed auth refusal as session/new (-32000/auth_required).
      if (error.code == -32000 || error.message.contains('auth')) {
        final data = error.data;
        final methods = <AcpAuthMethod>[
          if (data is Map && data['authMethods'] is List)
            for (final raw in data['authMethods'] as List)
              if (raw is Map)
                AcpAuthMethod.fromJson(raw.cast<String, Object?>()),
        ];
        throw AcpAuthRequiredException(
          message: error.message,
          authMethods: methods.isNotEmpty ? methods : _authMethods,
        );
      }
      rethrow;
    }
    final returned = result['sessionId'] as String?;
    _rememberModes(sessionId, result['modes']);
    return (returned == null || returned.isEmpty) ? sessionId : returned;
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
  ///
  /// The kill is awaited to verified death: SIGTERM, a bounded grace, then
  /// SIGKILL — dispose never returns while the agent still runs, and never
  /// leaves the kill fire-and-forget.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    await _subscription?.cancel();
    for (final completer in _pending.values) {
      completer.completeError(StateError('ACP client disposed'));
    }
    _pending.clear();
    final process = _process;
    if (process == null) {
      await onTransportDispose?.call();
      return;
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
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
        pending.completeError(
          error is Map
              ? AcpRemoteError.fromMap(error.cast<String, Object?>())
              : AcpRemoteError(0, '$error'),
        );
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
          if (AcpClientServices.isServiceMethod(method)) {
            final binding = services;
            if (binding == null) throw UnimplementedError();
            _respond(id, await binding.handle(method, params));
            return;
          }
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
    final options = (params['options'] as List<Object?>? ?? [])
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
    final expiry = meta['harnessPermissionExpiresAt'];
    final expiresAt = expiry is String ? DateTime.tryParse(expiry) : null;
    if (expiry != null && expiresAt == null) {
      throw const FormatException('invalid_permission_expiry');
    }
    final request = AcpPermissionRequest(
      sessionId: params['sessionId'] as String? ?? '',
      toolCallId: params['toolCallId'] as String? ?? '',
      title: meta['title'] as String? ?? '',
      kind: meta['kind'] as String? ?? 'other',
      details: meta['details'] as String?,
      expiresAt: expiresAt,
    );
    final outcome = await delegate(request);
    final wantedKind = switch (outcome) {
      AcpPermissionOutcome.allow => 'allow',
      AcpPermissionOutcome.reject => 'reject',
      AcpPermissionOutcome.cancelled => 'cancel',
    };
    final option = options.firstWhere(
      (o) => (o['kind'] as String?)?.startsWith(wantedKind) == true,
      orElse: () => wantedKind == 'allow'
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
