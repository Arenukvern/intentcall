// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'shop_search_tool.dart';

// **************************************************************************
// _AgentToolPartGenerator
// **************************************************************************

const _searchInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'query': <String, Object?>{'type': 'string', 'description': 'Query'},
  },
  'required': <String>['query'],
};

RegisteredAgentIntent get searchRegistration =>
    searchCallEntry.toRegistration();

AgentCallEntry get searchCallEntry => AgentCallEntry.tool(
  namespace: 'shop',
  name: 'search',
  description: 'Search catalog',
  inputSchema: _searchInputSchema,
  handler: (final args) async {
    final result = Function.apply(shopSearch, <Object?>[
      args['query'] as String,
    ], <Symbol, Object?>{});
    return await (result as Future<AgentResult>);
  },
);
