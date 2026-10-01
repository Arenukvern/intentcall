import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'instance_without_host_tool.g.dart';

final class DemoHostTools {
  DemoHostTools();

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
