import 'package:meta/meta.dart';

import '../naming/qualified_name.dart';
import 'agent_entity_property_role.dart';

enum AgentEntityPropertyValueType {
  string,
  integer,
  number,
  boolean,
  object,
  array,
}

enum AgentEntityPrivacy { public, private, sensitive }

@immutable
final class AgentEntityPropertyDescriptor {
  AgentEntityPropertyDescriptor({
    required this.name,
    required this.valueType,
    this.description = '',
    this.isDisplay = false,
    this.isSearchable = false,
    this.isIndexed = false,
    this.privacy,
    this.role = AgentEntityPropertyRole.none,
  }) {
    validateBareName(name);
  }

  final String name;
  final AgentEntityPropertyValueType valueType;
  final String description;
  final bool isDisplay;
  final bool isSearchable;
  final bool isIndexed;
  final AgentEntityPrivacy? privacy;
  final AgentEntityPropertyRole role;
}
