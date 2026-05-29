import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

extension AgentCallEntryTest on AgentCallEntry {
  Future<AgentResult> invokeWire(final Map<String, String> wire) =>
      invokeDirect(AgentWireArgs(wire).toAgentArguments());
}
