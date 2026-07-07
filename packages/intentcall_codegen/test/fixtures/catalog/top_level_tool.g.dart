// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'top_level_tool.dart';

// **************************************************************************
// _AgentToolPartGenerator
// **************************************************************************

const _catalog_pingInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'message': <String, Object?>{
      'type': 'string',
      'description': 'Message to echo',
    },
  },
  'required': <String>['message'],
};

RegisteredAgentIntent get catalogPingRegistration =>
    catalogPingCallEntry.toRegistration();

AgentCallEntry get catalogPingCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'catalog_ping',
  description: 'Returns pong for a message',
  inputSchema: _catalog_pingInputSchema,
  handler: (final args) async {
    final result = Function.apply(catalogPing, <Object?>[
      args['message'] as String,
    ], <Symbol, Object?>{});
    return await (result as Future<AgentResult>);
  },
);
