import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'static_method_tool.g.dart';

final class DemoHostTools {
  @AgentTool(
    namespace: 'app',
    name: 'demo_static',
    description: 'Static host tool',
  )
  static Future<AgentResult> demoStatic(
    @AgentParam('Message') String message,
  ) async {
    return AgentResult.success(data: {'message': message});
  }
}
