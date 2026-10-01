import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'demo_ping_tool.g.dart';

@AgentTool(
  namespace: 'app',
  name: 'demo_ping',
  description: 'Returns pong for a message',
)
Future<AgentResult> demoPing(
  @AgentParam('Message to echo') String message,
) async {
  return AgentResult.success(data: {'pong': message});
}

@AgentTool(
  namespace: 'app',
  name: 'demo_cart',
  description: 'Returns a cart total',
)
@AgentProjection(surfaces: {AgentManifestSurface.webMcp: false})
Future<AgentResult> demoCart(
  @AgentParam('Currency code') String currency, {
  @AgentParam('Include tax', required: false) bool includeTax = false,
}) async {
  return AgentResult.success(
    data: {'currency': currency, 'includeTax': includeTax},
  );
}

@AgentTool(
  namespace: 'app',
  name: 'demo_required_named',
  description: 'Returns a required named parameter',
)
Future<AgentResult> demoRequiredNamed({
  @AgentParam('Mode') String mode = 'fast',
}) async {
  return AgentResult.success(data: {'mode': mode});
}

/// Curated Apple verb for Siri / Shortcuts discovery (see `intentcall.yaml` ios/macos).
@AgentTool(
  namespace: 'app',
  name: 'demo_set_greeting',
  description: 'Set greeting text for the codegen demo host.',
)
@AgentProjection(
  surfaces: {
    AgentManifestSurface.appleAppIntents: true,
    AgentManifestSurface.appleAppShortcuts: true,
  },
)
Future<AgentResult> demoSetGreeting(
  @AgentParam('Greeting text') String text,
) async {
  return AgentResult.success(
    data: <String, Object?>{'greeting': text, 'kind': 'demo_set_greeting'},
  );
}
