import 'package:meta/meta.dart';

/// Normalized tool or resource invocation arguments after wire coercion.
///
/// Keys are parameter names from the registration [InputSchema]. Values are
/// JSON-compatible Dart types (`String`, `int`, `double`, `bool`, `List`,
/// `Map`) matching schema property types.
typedef AgentArguments = Map<String, Object?>;

/// JSON Schema–shaped map describing allowed tool or resource input.
///
/// Consumed by [validateAgainstSchema] and [coerceArgumentsForSchema].
/// Typically attached to `ToolRegistration` / `ResourceRegistration` in
/// `intentcall_core`.
typedef InputSchema = Map<String, Object?>;

/// String-key map as delivered by VM service extensions and some transports.
///
/// Parse with [AgentWireArgs] before coercion and validation.
typedef AgentWireMap = Map<String, String>;

/// Binary or text payload returned alongside structured result data on
/// [AgentResult].
///
/// Use [AgentArtifact.text] for UTF-8 text (default [mimeType]:
/// `text/plain`) or [AgentArtifact.bytes] for raw bytes with an explicit
/// [mimeType].
@immutable
final class AgentArtifact {
  /// Creates a text artifact.
  const AgentArtifact.text(this.text, {this.mimeType = 'text/plain'})
    : bytes = null;

  /// Creates a binary artifact.
  const AgentArtifact.bytes(this.bytes, {required this.mimeType}) : text = null;

  /// MIME type of the payload (for example `text/plain`, `application/json`).
  final String mimeType;

  /// UTF-8 text content when this is a text artifact.
  final String? text;

  /// Raw bytes when this is a binary artifact.
  final List<int>? bytes;
}

/// Outcome of an agent tool or resource handler invocation.
///
/// Every adapter maps this type to its transport (MCP `CallToolResult`, VM
/// service JSON, and so on). Handlers should not throw for expected failures;
/// return [AgentResult.failure] with a stable `code` instead.
///
/// ## Success
///
/// ```dart
/// AgentResult.success(
///   message: 'ok',
///   data: {'count': 3},
///   artifacts: [AgentArtifact.text('hello')],
/// );
/// ```
///
/// ## Failure
///
/// ```dart
/// AgentResult.failure(
///   code: 'invalid_state',
///   message: 'Cannot pause while idle.',
///   details: {'phase': 'idle'},
/// );
/// ```
@immutable
final class AgentResult {
  const AgentResult._({
    required this.ok,
    this.message = '',
    this.data = const {},
    this.artifacts = const [],
    this.code,
    this.details = const {},
  });

  /// Creates a successful result.
  ///
  /// [message] is a short human-readable summary (default `'ok'`).
  /// [data] holds structured JSON-safe fields for the client or agent.
  /// [artifacts] optionally attach text or binary payloads.
  factory AgentResult.success({
    final String message = 'ok',
    final Map<String, Object?> data = const {},
    final List<AgentArtifact> artifacts = const [],
  }) => AgentResult._(
    ok: true,
    message: message,
    data: data,
    artifacts: artifacts,
  );

  /// Creates a failed result.
  ///
  /// [code] should be a stable machine identifier (for example `not_found`).
  /// [message] explains the failure to humans and agents.
  /// [details] may carry extra JSON-safe context.
  factory AgentResult.failure({
    required final String code,
    required final String message,
    final Map<String, Object?> details = const {},
  }) =>
      AgentResult._(ok: false, code: code, message: message, details: details);

  /// Whether the invocation succeeded.
  final bool ok;

  /// Short human-readable summary of the outcome.
  final String message;

  /// Structured JSON-safe payload on success (or optional context on failure).
  final Map<String, Object?> data;

  /// Optional text or binary attachments.
  final List<AgentArtifact> artifacts;

  /// Stable error identifier when [ok] is `false`.
  final String? code;

  /// Extra JSON-safe context when [ok] is `false`.
  final Map<String, Object?> details;
}
