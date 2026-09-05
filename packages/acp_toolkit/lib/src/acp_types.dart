/// Content block for prompts and message chunks (ACP v1 subset).
sealed class AcpContentBlock {
  const AcpContentBlock();

  Map<String, Object?> toJson() => switch (this) {
    AcpTextBlock(:final text) => {'type': 'text', 'text': text},
  };

  static AcpContentBlock fromJson(Map<String, Object?> json) =>
      AcpTextBlock(json['text'] as String? ?? '');
}

class AcpTextBlock extends AcpContentBlock {
  const AcpTextBlock(this.text);
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};
}

/// Stop reasons returned at the end of a prompt turn.
enum AcpStopReason {
  endTurn('end_turn'),
  maxTokens('max_tokens'),
  maxTurnRequests('max_turn_requests'),
  refusal('refusal'),
  cancelled('cancelled');

  const AcpStopReason(this.wire);
  final String wire;

  static AcpStopReason fromWire(String wire) => AcpStopReason.values.firstWhere(
    (r) => r.wire == wire,
    orElse: () => AcpStopReason.endTurn,
  );
}

/// Parameters for `session/new`.
class AcpSessionNewRequest {
  const AcpSessionNewRequest({required this.cwd, this.mcpServers = const []});

  factory AcpSessionNewRequest.fromJson(Map<String, Object?> json) =>
      AcpSessionNewRequest(
        cwd: json['cwd'] as String? ?? '.',
        mcpServers: (json['mcpServers'] as List<Object?>? ?? [])
            .whereType<Map<String, Object?>>()
            .toList(),
      );

  /// Absolute working directory per spec; falls back to '.' when absent.
  final String cwd;
  final List<Map<String, Object?>> mcpServers;
}

/// Parameters for `session/prompt`.
class AcpPromptRequest {
  const AcpPromptRequest({
    required this.sessionId,
    required this.prompt,
    this.cancelled = false,
  });

  factory AcpPromptRequest.fromJson(Map<String, Object?> json) =>
      AcpPromptRequest(
        sessionId: json['sessionId'] as String? ?? '',
        prompt: (json['prompt'] as List<Object?>? ?? [])
            .whereType<Map<String, Object?>>()
            .map(AcpContentBlock.fromJson)
            .toList(),
      );

  final String sessionId;
  final List<AcpContentBlock> prompt;
  final bool cancelled;
}

/// Emitted by the backend during a prompt turn; forwarded as
/// `session/update` notifications.
sealed class AcpSessionUpdate {
  const AcpSessionUpdate();

  String get sessionUpdate => switch (this) {
    AgentMessageChunk() => 'agent_message_chunk',
    UserMessageChunk() => 'user_message_chunk',
    ToolCallUpdate() => 'tool_call_update',
    Plan() => 'plan',
    UnknownSessionUpdate(:final kind) => kind,
  };

  /// Decodes an inbound `session/update` payload.
  ///
  /// Unknown `sessionUpdate` kinds are preserved as [UnknownSessionUpdate]
  /// instead of throwing, so clients stay forward-compatible with newer
  /// agents.
  static AcpSessionUpdate fromJson(Map<String, Object?> json) {
    final update = json['sessionUpdate'] as String? ?? '';
    switch (update) {
      case 'agent_message_chunk':
        return AgentMessageChunk(
          content: AcpContentBlock.fromJson(
            (json['content'] as Map<String, Object?>?) ?? const {},
          ),
          messageId: json['messageId'] as String?,
        );
      case 'user_message_chunk':
        return UserMessageChunk(
          content: AcpContentBlock.fromJson(
            (json['content'] as Map<String, Object?>?) ?? const {},
          ),
          messageId: json['messageId'] as String?,
        );
      case 'tool_call_update':
        return ToolCallUpdate(
          toolCallId: json['toolCallId'] as String? ?? '',
          status: json['status'] as String? ?? 'pending',
          title: json['title'] as String?,
          kind: json['kind'] as String?,
          content: (json['content'] as List<Object?>?)
              ?.whereType<Map<String, Object?>>()
              .map(AcpContentBlock.fromJson)
              .toList(),
        );
      case 'plan':
        return Plan(
          entries: (json['entries'] as List<Object?>? ?? [])
              .whereType<Map<String, Object?>>()
              .map(
                (e) => PlanEntry(
                  content: e['content'] as String? ?? '',
                  priority: e['priority'] as String? ?? 'medium',
                  status: e['status'] as String? ?? 'pending',
                ),
              )
              .toList(),
        );
      default:
        return UnknownSessionUpdate(kind: update, raw: json);
    }
  }

  Map<String, Object?> toJson(String sessionId) {
    final update = <String, Object?>{
      'sessionUpdate': sessionUpdate,
      ..._payload(),
    };
    return {'sessionId': sessionId, 'update': update};
  }

  Map<String, Object?> _payload() => switch (this) {
    AgentMessageChunk(:final content, :final messageId) => {
      'content': content.toJson(),
      'messageId': ?messageId,
    },
    UserMessageChunk(:final content, :final messageId) => {
      'content': content.toJson(),
      'messageId': ?messageId,
    },
    ToolCallUpdate(
      :final toolCallId,
      :final title,
      :final kind,
      :final status,
      :final content,
    ) =>
      {
        'toolCallId': toolCallId,
        'title': ?title,
        'kind': ?kind,
        'status': status,
        if (content != null) 'content': content.map((c) => c.toJson()).toList(),
      },
    Plan(:final entries) => {
      'entries': entries
          .map(
            (e) => {
              'content': e.content,
              'priority': e.priority,
              'status': e.status,
            },
          )
          .toList(),
    },
    UnknownSessionUpdate() => const <String, Object?>{},
  };
}

class AgentMessageChunk extends AcpSessionUpdate {
  const AgentMessageChunk({required this.content, this.messageId});
  final AcpContentBlock content;
  final String? messageId;
}

class UserMessageChunk extends AcpSessionUpdate {
  const UserMessageChunk({required this.content, this.messageId});
  final AcpContentBlock content;
  final String? messageId;
}

/// Tool call lifecycle update. [status] is `pending`, `in_progress`, or
/// `completed`.
class ToolCallUpdate extends AcpSessionUpdate {
  const ToolCallUpdate({
    required this.toolCallId,
    required this.status,
    this.title,
    this.kind,
    this.content,
  });

  final String toolCallId;
  final String status;
  final String? title;
  final String? kind;
  final List<AcpContentBlock>? content;
}

class PlanEntry {
  const PlanEntry({
    required this.content,
    this.priority = 'medium',
    this.status = 'pending',
  });
  final String content;
  final String priority;
  final String status;
}

class Plan extends AcpSessionUpdate {
  const Plan({required this.entries});
  final List<PlanEntry> entries;
}

/// An unrecognized `session/update` kind from a newer agent.
///
/// Preserved verbatim in [raw] so callers can log or ignore it without
/// breaking the turn.
class UnknownSessionUpdate extends AcpSessionUpdate {
  const UnknownSessionUpdate({required this.kind, required this.raw});

  /// The unrecognized `sessionUpdate` discriminator (empty when missing).
  final String kind;

  /// The full inbound payload.
  final Map<String, Object?> raw;

  @override
  Map<String, Object?> _payload() => raw;
}

/// Permission request sent to the client via `session/request_permission`.
class AcpPermissionRequest {
  const AcpPermissionRequest({
    required this.sessionId,
    required this.toolCallId,
    required this.title,
    this.kind = 'other',
    this.details,
  });
  final String sessionId;
  final String toolCallId;
  final String title;
  final String kind;

  /// Optional human-facing detail block (e.g. the unified diff of the
  /// mutation under review) — surfaced by the client's consent UI so the
  /// human decides on the CHANGE, not just the path.
  final String? details;

  Map<String, Object?> toParams() => {
    'sessionId': sessionId,
    'options': [
      {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
      {'optionId': 'reject', 'name': 'Reject', 'kind': 'reject_once'},
    ],
    '_meta': {
      'title': title,
      'kind': kind,
      if (details != null) 'details': details,
    },
  };
}

/// Outcome of a permission request.
enum AcpPermissionOutcome { allow, reject, cancelled }

/// Client capabilities negotiated at initialize.
class AcpClientCapabilities {
  const AcpClientCapabilities({
    this.fsReadTextFile = false,
    this.fsWriteTextFile = false,
    this.terminal = false,
  });

  factory AcpClientCapabilities.fromJson(Map<String, Object?> json) {
    final fs = json['fs'] as Map<String, Object?>?;
    return AcpClientCapabilities(
      fsReadTextFile: fs?['readTextFile'] == true,
      fsWriteTextFile: fs?['writeTextFile'] == true,
      terminal: json['terminal'] == true,
    );
  }

  final bool fsReadTextFile;
  final bool fsWriteTextFile;
  final bool terminal;
}
