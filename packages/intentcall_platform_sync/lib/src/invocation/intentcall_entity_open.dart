final class IntentCallEntityOpenSource {
  const IntentCallEntityOpenSource._();

  static const String nativeEntityGenerated = 'native.entity.generated';
}

final class IntentCallEntityOpenEnvelope {
  IntentCallEntityOpenEnvelope({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.source,
    final DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory IntentCallEntityOpenEnvelope.fromJson(
    final Map<String, Object?> json,
  ) {
    return IntentCallEntityOpenEnvelope(
      id: '${json['id'] ?? ''}',
      entityType: '${json['entityType'] ?? ''}',
      entityId: '${json['entityId'] ?? ''}',
      source: '${json['source'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }

  final String id;
  final String entityType;
  final String entityId;
  final String source;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
  };
}
