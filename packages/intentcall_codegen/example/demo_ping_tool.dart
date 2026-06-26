import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'demo_ping_tool.g.dart';

@AgentTool(
  namespace: 'app',
  name: 'demo_ping',
  description: 'Returns pong for a message',
)
Future<AgentResult> demoPing(
  @AgentParam('Message to echo') String message,
) async {
  return AgentResult.success(data: {'pong': message});
}

@AgentTool(
  namespace: 'app',
  name: 'demo_cart',
  description: 'Returns a cart total',
)
Future<AgentResult> demoCart(
  @AgentParam('Currency code') String currency, {
  @AgentParam('Include tax', required: false) bool includeTax = false,
}) async {
  return AgentResult.success(
    data: {'currency': currency, 'includeTax': includeTax},
  );
}
