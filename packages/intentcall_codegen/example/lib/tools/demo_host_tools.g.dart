// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'demo_host_tools.dart';

// **************************************************************************
// _AgentToolPartGenerator
// **************************************************************************

const _demo_host_statusInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'label': <String, Object?>{'type': 'string', 'description': 'Host label'},
  },
  'required': <String>['label'],
};

extension DemoHostToolsAgentCodegen on DemoHostTools {
  AgentCallEntry get demoHostStatusCallEntry => AgentCallEntry.tool(
    namespace: 'app',
    name: 'demo_host_status',
    description: 'Codegen instance-method host tool',
    inputSchema: _demo_host_statusInputSchema,
    handler: (final args) async {
      return await hostStatus(args['label'] as String);
    },
  );
}

RegisteredAgentIntent get demoHostStatusRegistration =>
    DemoHostTools.shared.demoHostStatusCallEntry.toRegistration();
