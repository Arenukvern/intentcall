// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'demo_ping_tool.dart';

// **************************************************************************
// AgentToolGenerator
// **************************************************************************

const _demo_pingInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'message': <String, Object?>{
      'type': 'string',
      'description': 'Message to echo',
    },
  },
  'required': <String>['message'],
};

RegisteredAgentIntent get demoPingRegistration =>
    demoPingCallEntry.toRegistration();

AgentCallEntry get demoPingCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'demo_ping',
  description: 'Returns pong for a message',
  inputSchema: _demo_pingInputSchema,
  handler: (final args) async {
    final result = Function.apply(demoPing, <Object?>[
      args['message'] as String,
    ], <Symbol, Object?>{});
    return await (result as Future<AgentResult>);
  },
);

const _demo_cartInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'currency': <String, Object?>{
      'type': 'string',
      'description': 'Currency code',
    },
    'includeTax': <String, Object?>{
      'type': 'boolean',
      'description': 'Include tax',
    },
  },
  'required': <String>['currency'],
};

RegisteredAgentIntent get demoCartRegistration =>
    demoCartCallEntry.toRegistration();

AgentCallEntry get demoCartCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'demo_cart',
  description: 'Returns a cart total',
  inputSchema: _demo_cartInputSchema,
  handler: (final args) async {
    final result = Function.apply(
      demoCart,
      <Object?>[args['currency'] as String],
      <Symbol, Object?>{
        if (args.containsKey('includeTax'))
          #includeTax: args['includeTax'] as bool,
      },
    );
    return await (result as Future<AgentResult>);
  },
);

const _demo_required_namedInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'mode': <String, Object?>{'type': 'string', 'description': 'Mode'},
  },
  'required': <String>['mode'],
};

RegisteredAgentIntent get demoRequiredNamedRegistration =>
    demoRequiredNamedCallEntry.toRegistration();

AgentCallEntry get demoRequiredNamedCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'demo_required_named',
  description: 'Returns a required named parameter',
  inputSchema: _demo_required_namedInputSchema,
  handler: (final args) async {
    final result = Function.apply(
      demoRequiredNamed,
      <Object?>[],
      <Symbol, Object?>{#mode: args['mode'] as String},
    );
    return await (result as Future<AgentResult>);
  },
);
