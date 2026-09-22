import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';

import 'agent_link_directory.dart';
import 'agent_websocket_link.dart';
import 'intentcall_invocation.dart';

/// Asks the owner for its tool list. The reply is not broadcast.
Future<List<Map<String, Object?>>> listAgentWebSocketTools({
  required final Uri uri,
  final Duration timeout = const Duration(seconds: 5),
}) async {
  final socket = await WebSocket.connect(uri.toString());
  final completer = Completer<List<Map<String, Object?>>>();
  const requestId = 'list-1';
  late final StreamSubscription<dynamic> subscription;
  subscription = socket.listen((final raw) {
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['op'] != 'listed' || completer.isCompleted) {
      return;
    }
    if (decoded['id'] != requestId) {
      return;
    }
    final tools = decoded['tools'];
    completer.complete(<Map<String, Object?>>[
      if (tools is List)
        for (final tool in tools)
          if (tool is Map) Map<String, Object?>.from(tool),
    ]);
  });
  socket.add(jsonEncode(<String, Object?>{'op': 'list', 'id': requestId}));
  try {
    return await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
    await socket.close();
  }
}

/// Registry whose handlers forward to a discovered owner.
///
/// Used by `intentcall mcp serve --scheme`. Calling a tool does not copy the
/// owner's handler into this process.
Future<InMemoryAgentRegistry> registryFromDiscoveredLink(
  final AgentLinkAnnouncement announcement,
) async {
  final tools = await listAgentWebSocketTools(
    uri: Uri.parse(announcement.websocket),
  );
  final registry = InMemoryAgentRegistry();
  for (final tool in tools) {
    final name = '${tool['name'] ?? ''}';
    if (name.isEmpty) {
      continue;
    }
    final parts = name.split('_');
    final namespace = parts.length > 1 ? parts.first : 'app';
    final bare = parts.length > 1 ? parts.skip(1).join('_') : name;
    final schema = tool['inputSchema'];
    registry.register(
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: namespace,
          name: bare,
          description: '${tool['description'] ?? name}',
          kind: AgentIntentKind.tool,
          inputSchema: schema is Map
              ? Map<String, Object?>.from(schema)
              : const <String, Object?>{'type': 'object'},
        ),
        execute: (final invocation) => invokeAgentWebSocket(
          uri: Uri.parse(announcement.websocket),
          envelope: IntentCallInvocationEnvelope(
            id: 'mcp-proxy-${DateTime.now().microsecondsSinceEpoch}',
            qualifiedName: name,
            arguments: invocation.arguments,
            source: IntentCallInvocationSource.websocket,
          ),
        ),
      ),
      qualifiedNameOverride: name,
    );
  }
  return registry;
}
