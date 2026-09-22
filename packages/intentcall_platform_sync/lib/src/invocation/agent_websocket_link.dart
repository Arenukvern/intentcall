import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_http_invoke.dart';
import 'agent_link_directory.dart';
import 'agent_surface_link.dart';
import 'intentcall_invocation.dart';

/// Default [AgentSurfaceLink] transport for another process.
///
/// Frames are JSON text. Clients send
/// `{"op":"invoke","envelope":{...}}`. The server writes
/// `{"op":"observed","envelope":{...},"result":{...}}` to every connected
/// socket after each hub call, including HTTP and observed MCP calls.
///
/// Import this from `package:intentcall_platform_sync/io.dart` in VM or
/// server code only.
final class AgentWebSocketSurface {
  AgentWebSocketSurface._(
    this._server,
    this.link,
    this._subscription,
    this._directory,
    this._protocolScheme,
    this._announcement,
  );

  static const String path = '/agent/link';
  static const String discoverPath = '/agent/discover';

  final AgentSurfaceLink link;
  final HttpServer _server;
  final StreamSubscription<AgentCallObservation> _subscription;
  final AgentLinkDirectory? _directory;
  final String? _protocolScheme;
  final AgentLinkAnnouncement? _announcement;
  final Set<WebSocket> _sockets = <WebSocket>{};
  bool _closed = false;

  Uri get uri => Uri(
    scheme: 'ws',
    host: _server.address.host,
    port: _server.port,
    path: path,
  );

  static Future<AgentWebSocketSurface> serve({
    required final AgentSurfaceLink link,
    final InternetAddress? address,
    final int port = 0,
    final String? protocolScheme,
    final String owner = 'server',
    final AgentLinkDirectory? directory,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    final host = server.address.host;
    final boundPort = server.port;
    final scheme = protocolScheme?.trim();
    final announcement = scheme == null || scheme.isEmpty
        ? null
        : AgentLinkAnnouncement(
            protocolScheme: scheme,
            owner: owner,
            websocket: 'ws://$host:$boundPort$path',
            httpInvoke: 'http://$host:$boundPort${AgentHttpInvoke.defaultPath}',
            discover: 'http://$host:$boundPort$discoverPath',
          );
    late final AgentWebSocketSurface surface;
    // Cancelled in [close]. The server must outlive this listen call.
    // ignore: cancel_subscriptions
    final subscription = link.watch().listen((final observation) {
      surface._broadcast(observation);
    });
    surface = AgentWebSocketSurface._(
      server,
      link,
      subscription,
      announcement == null ? null : (directory ?? AgentLinkDirectory()),
      scheme,
      announcement,
    );
    if (announcement != null) {
      await surface._directory!.publish(announcement);
    }
    server.listen(surface._onRequest);
    return surface;
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final scheme = _protocolScheme;
    final directory = _directory;
    if (scheme != null && directory != null) {
      await directory.remove(scheme);
    }
    await _subscription.cancel();
    for (final socket in _sockets.toList()) {
      await socket.close();
    }
    await _server.close(force: true);
  }

  Future<void> _onRequest(final HttpRequest request) async {
    if (request.uri.path == discoverPath && request.method == 'GET') {
      final announcement = _announcement;
      request.response.statusCode = announcement == null
          ? HttpStatus.notFound
          : HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      if (announcement != null) {
        request.response.write(jsonEncode(announcement.toJson()));
      }
      await request.response.close();
      return;
    }
    if (request.uri.path == AgentHttpInvoke.defaultPath &&
        request.method == 'POST') {
      final body = await utf8.decodeStream(request);
      final payload = await AgentHttpInvoke.through(
        link,
      ).handle(requestUri: request.uri, body: body);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));
      await request.response.close();
      return;
    }
    if (request.uri.path != path ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen(
      (final raw) {
        unawaited(_onFrame(socket, raw));
      },
      onDone: () => _sockets.remove(socket),
      onError: (final _) => _sockets.remove(socket),
    );
  }

  Future<void> _onFrame(final WebSocket socket, final Object? raw) async {
    final decoded = _decodeMap(raw);
    if (decoded == null) {
      return;
    }
    if (decoded['op'] == 'list') {
      final tools = link is AgentInvocationHub
          ? (link as AgentInvocationHub).listTools()
          : const <Map<String, Object?>>[];
      _send(socket, <String, Object?>{
        'op': 'listed',
        'id': decoded['id'],
        'tools': tools,
      });
      return;
    }
    if (decoded['op'] != 'invoke') {
      return;
    }
    final envelopeRaw = decoded['envelope'];
    final envelope = IntentCallInvocationEnvelope.fromJson(
      envelopeRaw is Map
          ? Map<String, Object?>.from(envelopeRaw)
          : const <String, Object?>{},
    );
    try {
      await link.invoke(envelope);
    } on Object catch (error) {
      _send(socket, <String, Object?>{
        'op': 'observed',
        'envelope': envelope.toJson(),
        'result': <String, Object?>{
          'ok': false,
          'code': 'link_invoke_failed',
          'message': error.toString(),
        },
      });
    }
  }

  void _broadcast(final AgentCallObservation observation) {
    final result = observation.toJson()['result'];
    final frame = <String, Object?>{
      'op': 'observed',
      'envelope': observation.envelope.toJson(),
      'result': result is Map<String, Object?>
          ? result
          : const <String, Object?>{},
    };
    for (final socket in _sockets.toList()) {
      _send(socket, frame);
    }
  }

  void _send(final WebSocket socket, final Map<String, Object?> frame) {
    if (socket.readyState != WebSocket.open) {
      _sockets.remove(socket);
      return;
    }
    socket.add(jsonEncode(frame));
  }
}

/// Sends one `invoke` frame and waits for the matching `observed` result.
Future<AgentResult> invokeAgentWebSocket({
  required final Uri uri,
  required final IntentCallInvocationEnvelope envelope,
  final Duration timeout = const Duration(seconds: 5),
}) async {
  final socket = await WebSocket.connect(uri.toString());
  final completer = Completer<AgentResult>();
  late final StreamSubscription<dynamic> subscription;
  subscription = socket.listen((final raw) {
    final decoded = _decodeMap(raw);
    if (decoded == null || decoded['op'] != 'observed') {
      return;
    }
    final observation = AgentCallObservation.fromJson(decoded);
    if (observation.envelope.id != envelope.id || completer.isCompleted) {
      return;
    }
    completer.complete(observation.result);
  });
  socket.add(
    jsonEncode(<String, Object?>{
      'op': 'invoke',
      'envelope': envelope.toJson(),
    }),
  );
  try {
    return await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
    await socket.close();
  }
}

Map<String, Object?>? _decodeMap(final Object? raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw is String ? raw : utf8.decode(raw! as List<int>));
  } on Object {
    return null;
  }
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, Object?>.from(decoded);
  }
  return null;
}
