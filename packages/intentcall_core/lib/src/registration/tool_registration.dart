import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:meta/meta.dart';

/// Handler for a capability tool using transport-agnostic [AgentResult].
typedef ToolHandler = Future<AgentResult> Function(AgentArguments arguments);

/// A tool a capability wants a host to expose.
///
/// [name] is the bare tool name. Hosts can apply their own namespace or
/// transport naming policy when publishing the tool.
@immutable
final class ToolRegistration {
  const ToolRegistration({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final ToolHandler handler;
}
