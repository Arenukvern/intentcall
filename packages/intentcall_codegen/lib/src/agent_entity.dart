/// Declares one property on an @[AgentEntity] type for catalog projection.
class AgentEntityProperty {
  const AgentEntityProperty({
    required this.name,
    this.valueType = 'string',
    this.description = '',
    this.isDisplay = false,
    this.isSearchable = false,
    this.isIndexed = false,
    this.role = 'none',
  });

  final String name;
  final String valueType;
  final String description;
  final bool isDisplay;
  final bool isSearchable;
  final bool isIndexed;

  /// Semantic snapshot role: `none`, `title`, `subtitle`, or `keywords`.
  ///
  /// Entity-level [AgentEntity.titleProperty] / [subtitleProperty] /
  /// [keywordsProperty] overrides win when they name this property.
  final String role;
}

/// Marks a class declaring an app entity type for catalog + manifest export.
///
/// [AgentCatalogGenerator] discovers annotated classes under `lib/` and emits
/// descriptor rows into `lib/generated/agent_catalog.g.dart`.
class AgentEntity {
  const AgentEntity({
    required this.namespace,
    required this.name,
    required this.identifierName,
    this.displayName,
    this.properties = const <AgentEntityProperty>[],
    this.titleProperty,
    this.subtitleProperty,
    this.keywordsProperty,
    this.privacy = 'private',
    this.deepLinkBehavior = 'unsupported',
    this.openBehavior = 'unsupported',
  });

  final String namespace;
  final String name;
  final String identifierName;
  final String? displayName;
  final List<AgentEntityProperty> properties;

  /// Assigns [AgentEntityPropertyRole.title] to the named property in codegen.
  final String? titleProperty;

  /// Assigns [AgentEntityPropertyRole.subtitle] to the named property in codegen.
  final String? subtitleProperty;

  /// Assigns [AgentEntityPropertyRole.keywords] to the named property in codegen.
  final String? keywordsProperty;

  final String privacy;
  final String deepLinkBehavior;
  final String openBehavior;
}
