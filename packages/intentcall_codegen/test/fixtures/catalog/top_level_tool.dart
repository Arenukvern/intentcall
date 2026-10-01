import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'top_level_tool.g.dart';

@AgentTool(
  namespace: 'app',
  name: 'catalog_ping',
  description: 'Returns pong for a message',
)
Future<AgentResult> catalogPing(
  @AgentParam('Message to echo') String message,
) async {
  return AgentResult.success(data: {'pong': message});
}
