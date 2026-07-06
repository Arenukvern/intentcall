import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'demo_ping_tool.g.dart';

@AgentTool(name: 'demo_ping', description: 'Returns pong for a message')
Future<AgentResult> demoPing(
  @AgentParam('Message to echo') final String message,
) async => AgentResult.success(data: {'pong': message});
