import 'acp_types.dart';

/// The REMOTE MOVER contract (R7 production #4) — server→client
/// `session/propose_move`.
///
/// The daemon runs the harness loop; the CLIENT (e.g. pi's model) is the
/// session actor's brain: it receives a bounded cut (`prompt`), the tool
/// schemas it may call, and the budgets that bound it, and answers with
/// TYPED tool calls. Bounded protocol only: no file text, no AST, no raw
/// tree — what the model may see is exactly what the projection law
/// allows. The host validates, materializes, and verifies every proposed
/// move; the client never executes anything.

/// The parameters of one server→client `session/propose_move` request.
class AcpMoveProposal {
  const AcpMoveProposal({
    required this.sessionId,
    required this.decisionId,
    required this.prompt,
    required this.toolSchemas,
    required this.budgets,
    this.reasoning = 'high',
  });

  final String sessionId;

  /// Unique per round-trip — the client's answer MUST carry it back so
  /// concurrent proposals cannot cross (one actor at a time in v1, but
  /// the id makes the protocol race-free by construction).
  final String decisionId;

  /// The bounded cut the actor's decision sees (the projected situation —
  /// NEVER file text; the projection law holds end to end).
  final String prompt;

  /// `[{name, description, parameters}]` — the closed tool surface the
  /// actor may call this decision. Schema-carrying: the client renders
  /// them to its model, the model's tool calls come back typed.
  final List<Map<String, Object?>> toolSchemas;

  /// The budgets THIS decision runs under (consumed in-world by the
  /// daemon loop, not by the client — the client only sees what's left).
  final Map<String, Object?> budgets;

  /// Reasoning-policy hint for this decision class (ADR 0027):
  /// `none` (mechanical/routine moves — cheap model or thinking off),
  /// `low` (structured edits), `high` (decomposition/planning/repair).
  /// The daemon classifies; the client maps it to its model config.
  final String reasoning;

  Map<String, Object?> toParams() => {
    'sessionId': sessionId,
    'decisionId': decisionId,
    'prompt': prompt,
    'toolSchemas': toolSchemas,
    'budgets': budgets,
    'reasoning': reasoning,
  };
}

/// One typed tool call the client's model proposes.
class AcpMoveToolCall {
  const AcpMoveToolCall({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;

  Map<String, Object?> toJson() => {'name': name, 'arguments': arguments};
}

/// The client's answer to one `session/propose_move`.
class AcpMoveResponse {
  const AcpMoveResponse({
    this.toolCalls = const [],
    this.text = '',
    this.thinking = '',
  });

  factory AcpMoveResponse.fromJson(Map<String, Object?> json) =>
      AcpMoveResponse(
        toolCalls: [
          if (json['toolCalls'] is List)
            for (final c in json['toolCalls'] as List)
              if (c is Map)
                AcpMoveToolCall(
                  name: c['name'] as String? ?? '',
                  arguments:
                      (c['arguments'] as Map?)?.cast<String, dynamic>() ??
                      const {},
                ),
        ],
        text: json['text'] as String? ?? '',
        // ADR 0027: the client's reasoning, captured by the daemon as a
        // reasoning record (measured, never re-projected, reused on
        // escalation). Additive — absent on older clients.
        thinking: json['thinking'] as String? ?? '',
      );

  /// Typed tool calls the actor emits THIS decision (empty = the model is
  /// done — the loop closes the chain and the goal gate grades).
  final List<AcpMoveToolCall> toolCalls;

  /// Short narration (streams to the client as a message chunk).
  final String text;

  /// The client's reasoning text for this decision (ADR 0027). Captured
  /// by the daemon as a reasoning record — measured (chars), never
  /// re-projected into future cuts, reused on escalation. NOT streamed
  /// back to the client.
  final String thinking;
}

/// Optional capability for backends whose session actor's brain lives on
/// the CLIENT (the remote mover): the daemon runs the loop; every
/// decision round-trips to the client as `session/propose_move` (bounded
/// cut + tool schemas out, typed tool calls back — the same JSON-RPC
/// pattern as `session/request_permission`).
abstract interface class AcpMoveProposing {
  /// Called once by the server before the first message is dispatched.
  void attachMoveProposer(
    Future<AcpMoveResponse> Function(AcpMoveProposal proposal) proposer,
  );
}
