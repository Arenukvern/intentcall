/// Thrown when [validateAgainstSchema] rejects [AgentArguments].
///
/// The [message] is intended for humans and agents (for example
/// `Missing required property "uri".` or `"count" must be an integer.`).
/// Adapters may map this to transport-specific validation errors.
final class AgentValidationException implements Exception {
  /// Creates a validation error with the given [message].
  AgentValidationException(this.message);

  /// Human-readable description of the validation failure.
  final String message;

  @override
  String toString() => 'AgentValidationException: $message';
}
