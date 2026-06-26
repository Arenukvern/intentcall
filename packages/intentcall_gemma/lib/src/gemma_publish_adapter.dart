import 'package:intentcall_core/intentcall_core.dart';
import 'package:meta/meta.dart';

/// Gemma function-calling tool definition (maps to flutter_gemma `tools` JSON).
@immutable
final class GemmaToolDefinition {
  const GemmaToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> parametersSchema;
}

/// Invoked when Gemma returns a function call for [name].
typedef GemmaToolInvoker =
    Future<Map<String, Object?>> Function(Map<String, Object?> arguments);

typedef GemmaToolRegistrar =
    void Function(GemmaToolDefinition definition, GemmaToolInvoker invoker);

typedef GemmaToolUnregistrar = void Function(String name);

/// Maps [AgentRegistry] tool intents to on-device Gemma tool definitions.
final class GemmaPublishAdapter implements AgentAdapter {
  GemmaPublishAdapter({required this.register, required this.unregister});

  final GemmaToolRegistrar register;
  final GemmaToolUnregistrar unregister;

  @override
  String get id => 'gemma';

  @override
  bool get watchesRegistry => false;

  final List<String> _registered = <String>[];

  @override
  Future<void> attach(final AgentRegistry registry) async {
    for (final entry in registry.listEntries()) {
      if (entry.descriptor.kind == AgentIntentKind.tool) {
        _registerTool(registry, key: entry.key, descriptor: entry.descriptor);
      }
    }
  }

  @override
  Future<void> detach() async {
    _registered.toList().forEach(unregister);
    _registered.clear();
  }

  void _registerTool(
    final AgentRegistry registry, {
    required final String key,
    required final AgentIntentDescriptor descriptor,
  }) {
    final name = key;
    register(
      GemmaToolDefinition(
        name: name,
        description: descriptor.description,
        parametersSchema: descriptor.inputSchema,
      ),
      (final arguments) async {
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
    _registered.add(name);
  }
}
