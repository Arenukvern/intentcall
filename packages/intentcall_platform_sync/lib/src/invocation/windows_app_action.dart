import 'dart:convert';

import 'package:intentcall_schema/intentcall_schema.dart';

import 'intentcall_invocation.dart';

/// Maps one Windows App Actions URI invocation onto the Dart registry.
///
/// The packaged runner parses `scheme://actions/<qualifiedName>`, checks the
/// Windows caller, then calls this helper. [result] is the Text entity value:
/// `AgentResult` JSON, including failures. URI launch completes the activation
/// with that text; it does not have a separate failure channel.
Future<Map<String, Object?>> executeWindowsAppAction({
  required final IntentCallNativeBridge bridge,
  required final String qualifiedName,
  required final Map<String, Object?> inputs,
  final String? invocationId,
}) async {
  final result = await bridge.execute(
    IntentCallInvocationEnvelope(
      id:
          invocationId ??
          'windows-app-action-${DateTime.now().microsecondsSinceEpoch}',
      qualifiedName: qualifiedName,
      arguments: inputs,
      source: IntentCallInvocationSource.windowsAppAction,
    ),
  );
  return <String, Object?>{'result': jsonEncode(_payload(result))};
}

Map<String, Object?> _payload(final AgentResult result) {
  if (!result.ok) {
    return <String, Object?>{
      'ok': false,
      'code': result.code,
      'message': result.message,
      if (result.details.isNotEmpty) 'details': result.details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}
