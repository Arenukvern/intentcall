/// Wire types, validation, and result envelopes for IntentCall.
///
/// This library is the **transport-neutral contract** between app handlers,
/// the `intentcall_core` registry, and adapters (MCP, WebMCP, platform sync).
///
/// It has no Flutter dependency.
///
/// ## For app and adapter authors (DX)
///
/// - Return [AgentResult] from tool and resource handlers.
/// - Attach an [InputSchema] to registrations in `intentcall_core`.
/// - Parse VM service extension maps with [AgentWireArgs], then run
///   [coerceArgumentsForSchema] and [validateAgainstSchema] before invoke.
///
/// ## For agents and clients (AX)
///
/// - Tool outcomes are [AgentResult] values serialized to JSON by adapters.
/// - [AgentResultEnvelope] builds versioned snapshot payloads (`schema_version`,
///   `kind`, `snapshot`, `resource_uri`, …) that MCP and inspector clients consume.
/// - [AgentEntitySnapshot] describes indexable app objects (`ref`, `properties`,
///   display fields) for search, shortcuts, and deep links.
///
/// See also: [intentcall_core on pub.dev](https://pub.dev/packages/intentcall_core).
library;

export 'src/agent_entity_model.dart';
export 'src/agent_result.dart';
export 'src/agent_result_envelope.dart';
export 'src/agent_validation_exception.dart';
export 'src/agent_wire_args.dart';
export 'src/client_resource_input_schemas.dart';
export 'src/schema_coercion.dart';
export 'src/schema_validator.dart';
