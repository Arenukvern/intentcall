import 'package:intentcall_schema/intentcall_schema.dart' as schema;
import 'package:meta/meta.dart';

import '../models/qualified_name.dart';
import 'agent_automation_hint.dart';
import 'agent_intent_kind.dart';

@immutable
final class AgentIntentDescriptor {
  AgentIntentDescriptor({
    required this.namespace,
    required this.name,
    required this.description,
    required this.kind,
    required this.inputSchema,
    this.methodName,
    this.resourceUri,
    this.mimeType,
    this.automation,
  }) {
    validateNamespace(namespace);
    validateBareName(name);
  }

  final String namespace;
  final String name;
  final String description;
  final AgentIntentKind kind;
  final schema.InputSchema inputSchema;
  final String? methodName;
  final String? resourceUri;
  final String? mimeType;

  /// Optional driver-routing hint (ADR 0038): how an `AutomationDriver`
  /// could execute this intent. IntentCall never drives; it only states.
  final IntentAutomationHint? automation;

  String get qualifiedName => qualifyName(namespace: namespace, name: name);

  String get effectiveMethodName => methodName ?? name;

  String effectiveResourceUri(final String protocolScheme) =>
      resourceUri ??
      schema.resourceUri(protocolScheme: protocolScheme, resourceName: name);
}
