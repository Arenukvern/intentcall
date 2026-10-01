import 'package:intentcall_core/intentcall_core.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';
import 'agent_web_mcp_bootstrap.dart';

/// Composable WebMCP surface for the mcp_flutter toolkit's projection SPI
/// (mcp_flutter ADR-0016).
///
/// Deliberately duck-typed: [entriesChanged] matches mcp_toolkit's
/// `ToolkitProjection.entriesChanged`, so apps pass
/// `WebMcpProjection(policy: myPolicy).entriesChanged` where the toolkit
/// expects a projection — without this package depending on the toolkit.
///
/// The policy is **required**: the projection never chooses an
/// authorization posture silently (the toolkit's former hard-wired
/// registration applied `debugAllowAll()` invisibly — that anti-pattern is
/// what this class exists to replace).
final class WebMcpProjection {
  const WebMcpProjection({required this.policy, this.surfaceIndex});

  /// Who may invoke the projected tools on the browser WebMCP registry.
  final IntentCallAuthorizationPolicy policy;

  /// Optional manifest surface index for qualified-name allowlists.
  final ManifestSurfaceIndex? surfaceIndex;

  /// Re-projects the toolkit's full current entry set (idempotent).
  void entriesChanged(final Set<AgentCallEntry> entries) =>
      projectEntriesToWebMcp(entries, policy: policy, surfaceIndex: surfaceIndex);
}
