import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'host_instance_tool.g.dart';

final class DemoHostTools {
  DemoHostTools();

  static final DemoHostTools shared = DemoHostTools();

  @AgentTool(
    namespace: 'app',
    name: 'demo_inbox',
    description: 'Read inbox folder',
  )
  Future<AgentResult> inbox(
    @AgentParam('Inbox folder name') String folder,
  ) async {
    return AgentResult.success(data: {'folder': folder});
  }
}
