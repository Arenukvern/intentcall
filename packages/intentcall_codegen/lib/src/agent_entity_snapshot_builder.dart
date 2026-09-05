import 'package:intentcall_core/intentcall_core.dart';

/// Builds entity snapshot property maps using [AgentEntitySnapshotKeys].
///
/// Prefer generated `{Namespace}{Name}EntityFields` constants for property
/// names; this helper maps values onto the resolved snapshot keys from the
/// catalog descriptor.
final class AgentEntitySnapshotBuilder {
  AgentEntitySnapshotBuilder(this.descriptor)
    : keys = AgentEntitySnapshotKeys.fromDescriptor(descriptor);

  final AgentEntityTypeDescriptor descriptor;
  final AgentEntitySnapshotKeys keys;

  /// Returns a property map keyed by descriptor field names.
  ///
  /// Pass [values] keyed by property name (for example
  /// `AppProjectEntityFields.name`). The identifier is written under
  /// [AgentEntitySnapshotKeys.idKey].
  Map<String, Object?> buildProperties({
    required final String identifier,
    required final Map<String, Object?> values,
  }) {
    final row = <String, Object?>{keys.idKey: identifier};
    for (final property in descriptor.properties) {
      if (!values.containsKey(property.name)) {
        continue;
      }
      row[property.name] = values[property.name];
    }
    return row;
  }
}
