import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';

/// Callback surface matching WebMCP modelContext tool registration.
typedef WebMcpToolPublisher =
    void Function({
      required String name,
      required String description,
      required Map<String, Object?> inputSchema,
      required Future<Map<String, Object?>> Function(
        Map<String, Object?> arguments,
      )
      execute,
    });

typedef WebMcpToolUnpublisher = void Function(String name);

/// Publishes registry tool intents to a WebMCP-compatible surface.
///
/// In the browser, wire [publish] to `document.modelContext.registerTool`.
/// Older experiments exposed `navigator.modelContext`; support that only as a
/// compatibility shim.
/// On VM/test, use an in-memory fake (see tests).
final class WebMcpPublishAdapter implements AgentAdapter {
  WebMcpPublishAdapter({required this.publish, required this.unpublish});

  final WebMcpToolPublisher publish;
  final WebMcpToolUnpublisher unpublish;

  @override
  String get id => 'webmcp';

  @override
  bool get watchesRegistry => true;

  final List<String> _published = <String>[];
  StreamSubscription<AgentRegistryEvent>? _events;
  AgentRegistry? _registry;

  @override
  Future<void> attach(final AgentRegistry registry) async {
    _registry = registry;
    for (final entry in registry.listEntries()) {
      if (entry.descriptor.kind == AgentIntentKind.tool) {
        _publishTool(registry, key: entry.key, descriptor: entry.descriptor);
      }
    }
    _events = registry.events.listen((final event) {
      final reg = _registry;
      if (reg == null) return;
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = reg.get(qualifiedName);
          if (intent != null &&
              intent.descriptor.kind == AgentIntentKind.tool) {
            _publishTool(
              reg,
              key: qualifiedName,
              descriptor: intent.descriptor,
            );
          }
        case IntentUnregistered(:final qualifiedName):
          _unpublish(qualifiedName);
      }
    });
  }

  @override
  Future<void> detach() async {
    await _events?.cancel();
    _events = null;
    _published.toList().forEach(_unpublish);
    _registry = null;
  }

  void _publishTool(
    final AgentRegistry registry, {
    required final String key,
    required final AgentIntentDescriptor descriptor,
  }) {
    final name = key;
    if (_published.contains(name)) return;
    publish(
      name: name,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      execute: (final arguments) async {
        final result = await registry.invoke(name, arguments);
        if (!result.ok) {
          return <String, Object?>{
            'ok': false,
            'code': result.code,
            'message': result.message,
            'details': result.details,
          };
        }
        return <String, Object?>{'ok': true, ...result.data};
      },
    );
    _published.add(name);
  }

  void _unpublish(final String name) {
    if (!_published.remove(name)) return;
    unpublish(name);
  }
}
