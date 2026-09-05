// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'cart_total_tool.dart';

// **************************************************************************
// _AgentToolPartGenerator
// **************************************************************************

const _cart_totalInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'currency': <String, Object?>{
      'type': 'string',
      'description': 'Currency code',
    },
  },
  'required': <String>['currency'],
};

RegisteredAgentIntent get cartTotalRegistration =>
    cartTotalCallEntry.toRegistration();

AgentCallEntry get cartTotalCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'cart_total',
  description: 'Return cart total',
  inputSchema: _cart_totalInputSchema,
  handler: (final args) async {
    final result = Function.apply(cartTotal, <Object?>[
      args['currency'] as String,
    ], <Symbol, Object?>{});
    return await (result as Future<AgentResult>);
  },
);
