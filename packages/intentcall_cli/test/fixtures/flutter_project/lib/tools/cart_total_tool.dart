import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'cart_total_tool.g.dart';

@AgentTool(name: 'cart_total', description: 'Return cart total')
Future<AgentResult> cartTotal(
  @AgentParam('Currency code') final String currency,
) async => AgentResult.success(data: {'currency': currency});
