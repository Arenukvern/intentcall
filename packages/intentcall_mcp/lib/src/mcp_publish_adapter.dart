import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:intentcall_core/intentcall_core.dart';

import 'agent_bridge.dart';
import 'mcp_resource_mapper.dart';
import 'mcp_result_mapper.dart';
import 'uri_template.dart';

typedef McpToolPublisher =
    void Function(
      Tool tool,
      FutureOr<CallToolResult> Function(CallToolRequest request) impl,
    );

typedef McpToolUnpublisher = void Function(String name);

typedef McpResourcePublisher =
    void Function(
      Resource resource,
      FutureOr<ReadResourceResult> Function(ReadResourceRequest request) impl,
    );

typedef McpResourceUnpublisher = void Function(String uri);

typedef McpResourceTemplatePublisher =
    void Function(
      ResourceTemplate template,
      FutureOr<ReadResourceResult?> Function(ReadResourceRequest request) impl,
    );

/// Publishes registry-backed tools and resources to dart_mcp.
final class McpPublishAdapter implements AgentAdapter {
  McpPublishAdapter({
    required this.publishTool,
    required this.unpublishTool,
    this.publishResource,
    this.unpublishResource,
    this.publishResourceTemplate,
    this.protocolScheme,
  });

  final McpToolPublisher publishTool;
  final McpToolUnpublisher unpublishTool;
  final McpResourcePublisher? publishResource;
  final McpResourceUnpublisher? unpublishResource;
  final McpResourceTemplatePublisher? publishResourceTemplate;

  /// App-owned scheme used when a resource descriptor has no explicit [AgentIntentDescriptor.resourceUri].
  final String? protocolScheme;

  final Set<String> _publishedTools = <String>{};
  final Set<String> _publishedResources = <String>{};
  final Set<String> _publishedResourceTemplates = <String>{};
  final Set<String> _publishedResourceTemplatePatterns = <String>{};
  final Map<String, String> _resourceTemplatePatternByKey = <String, String>{};
  StreamSubscription<AgentRegistryEvent>? _events;
  AgentRegistry? _registry;

  @override
  String get id => 'mcp';

  @override
  bool get watchesRegistry => true;

  @override
  Future<void> attach(final AgentRegistry registry) async {
    _registry = registry;
    for (final entry in registry.listEntries()) {
      _syncDescriptor(registry, entry.descriptor, registryKey: entry.key);
    }
    _events = registry.events.listen((final event) {
      final reg = _registry;
      if (reg == null) return;
      switch (event) {
        case IntentRegistered(:final qualifiedName):
          final intent = reg.get(qualifiedName);
          if (intent != null) {
            _syncDescriptor(reg, intent.descriptor, registryKey: qualifiedName);
          }
        case IntentUnregistered(:final qualifiedName):
          _unpublishTransportKey(qualifiedName);
        case EntityTypeRegistered() || EntityTypeUnregistered():
          break;
      }
    });
  }

  @override
  Future<void> detach() async {
    await _events?.cancel();
    _events = null;
    unpublishAll();
    _registry = null;
  }

  void publishCapabilityTool({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ToolRegistration registration,
    required final String fullName,
  }) {
    registry.register(
      toolRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: fullName,
    );
  }

  void publishCapabilityResource({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ResourceRegistration registration,
  }) {
    registry.register(
      resourceRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: registration.uri,
    );
  }

  void publishCapabilityResourceTemplate({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ResourceTemplateRegistration registration,
  }) {
    registry.register(
      resourceTemplateRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: registration.uriTemplate,
    );
  }

  void unpublishRegistryTool({
    required final AgentRegistry registry,
    required final String fullName,
  }) {
    _unpublishTransportKey(fullName);
  }

  void unpublishRegistryResource({
    required final AgentRegistry registry,
    required final String uri,
  }) {
    _unpublishTransportKey(uri);
  }

  void unpublishAll({final AgentRegistry? registry}) {
    _publishedTools.toList().forEach(_unpublishTransportKey);
    _publishedResources.toList().forEach(_unpublishTransportKey);
    _publishedResourceTemplates.toList().forEach(_unpublishTransportKey);
  }

  void unpublishRegistryResourceTemplate({
    required final AgentRegistry registry,
    required final String uriTemplate,
  }) {
    _unpublishTransportKey(uriTemplate);
  }

  void _syncDescriptor(
    final AgentRegistry registry,
    final AgentIntentDescriptor descriptor, {
    final String? registryKey,
  }) {
    final key = registryKey ?? descriptor.qualifiedName;
    if (descriptor.kind == AgentIntentKind.tool) {
      if (_publishedTools.contains(key)) return;
      _publishToolIntent(registry: registry, key: key, descriptor: descriptor);
    } else if (publishResource != null || publishResourceTemplate != null) {
      if (_publishedResources.contains(key)) return;
      if (_publishedResourceTemplates.contains(key)) return;
      if (descriptor.resourceUri?.contains('{') ?? false) {
        _publishResourceTemplateIntent(
          registry: registry,
          key: key,
          descriptor: descriptor,
        );
      } else {
        _publishResourceIntent(
          registry: registry,
          key: key,
          descriptor: descriptor,
        );
      }
    }
  }

  void _publishToolIntent({
    required final AgentRegistry registry,
    required final String key,
    required final AgentIntentDescriptor descriptor,
  }) {
    publishTool(
      Tool(
        name: key,
        description: descriptor.description,
        inputSchema: ObjectSchema.fromMap(descriptor.inputSchema),
      ),
      (final request) async => agentResultToMcpResult(
        await registry.invoke(
          key,
          request.arguments ?? const <String, Object?>{},
        ),
      ),
    );
    _publishedTools.add(key);
  }

  void _publishResourceIntent({
    required final AgentRegistry registry,
    required final String key,
    final ResourceRegistration? registration,
    final AgentIntentDescriptor? descriptor,
  }) {
    final publish = publishResource;
    if (publish == null) return;
    final d =
        descriptor ??
        AgentIntentDescriptor(
          namespace: 'resource',
          name: registration!.name,
          description: registration.description,
          kind: AgentIntentKind.resource,
          inputSchema: const <String, Object?>{'type': 'object'},
          resourceUri: registration.uri,
          mimeType: registration.mimeType,
        );
    publish(
      Resource(
        uri: registration?.uri ?? _resolvedResourceUri(d),
        name: registration?.name ?? d.name,
        description: registration?.description ?? d.description,
        mimeType: registration?.mimeType ?? d.mimeType ?? 'application/json',
      ),
      (final request) async => agentResultToReadResourceResult(
        await registry.invoke(key, <String, Object?>{'uri': request.uri}),
        uri: request.uri,
      ),
    );
    _publishedResources.add(key);

    final publishTemplate = publishResourceTemplate;
    if (publishTemplate == null || _publishedResourceTemplates.contains(key)) {
      return;
    }
    final uriTemplate = registration?.uri ?? _resolvedResourceUri(d);
    if (_publishedResourceTemplatePatterns.contains(uriTemplate)) {
      return;
    }
    publishTemplate(
      ResourceTemplate(
        uriTemplate: uriTemplate,
        name: registration?.name ?? d.name,
        description: registration?.description ?? d.description,
        mimeType: registration?.mimeType ?? d.mimeType ?? 'application/json',
      ),
      (final request) async {
        final params = matchUriTemplate(uriTemplate, request.uri);
        if (params == null) return null;
        return agentResultToReadResourceResult(
          await registry.invoke(key, <String, Object?>{'uri': request.uri}),
          uri: request.uri,
        );
      },
    );
    _publishedResourceTemplates.add(key);
    _publishedResourceTemplatePatterns.add(uriTemplate);
    _resourceTemplatePatternByKey[key] = uriTemplate;
  }

  void _publishResourceTemplateIntent({
    required final AgentRegistry registry,
    required final String key,
    final ResourceTemplateRegistration? registration,
    final AgentIntentDescriptor? descriptor,
  }) {
    final publish = publishResourceTemplate;
    if (publish == null) return;
    final uriTemplate = registration?.uriTemplate ?? descriptor!.resourceUri!;
    if (_publishedResourceTemplatePatterns.contains(uriTemplate)) {
      return;
    }
    publish(
      ResourceTemplate(
        uriTemplate: uriTemplate,
        name: registration?.name ?? descriptor!.name,
        description: registration?.description ?? descriptor!.description,
        mimeType:
            registration?.mimeType ??
            descriptor!.mimeType ??
            'application/json',
      ),
      (final request) async {
        final params = matchUriTemplate(uriTemplate, request.uri);
        if (params == null) return null;
        return agentResultToReadResourceResult(
          await registry.invoke(key, <String, Object?>{
            'uri': request.uri,
            ...params,
          }),
          uri: request.uri,
        );
      },
    );
    _publishedResourceTemplates.add(key);
    _publishedResourceTemplatePatterns.add(uriTemplate);
    _resourceTemplatePatternByKey[key] = uriTemplate;
  }

  String _resolvedResourceUri(final AgentIntentDescriptor descriptor) {
    if (descriptor.resourceUri != null) {
      return descriptor.resourceUri!;
    }
    final scheme = protocolScheme?.trim() ?? '';
    if (scheme.isEmpty) {
      throw StateError(
        'McpPublishAdapter needs protocolScheme for resource '
        '"${descriptor.qualifiedName}" without an explicit resourceUri.',
      );
    }
    return descriptor.effectiveResourceUri(scheme);
  }

  void _unpublishTransportKey(final String key) {
    if (_publishedTools.remove(key)) {
      unpublishTool(key);
    }
    if (_publishedResources.remove(key)) {
      unpublishResource?.call(key);
    }
    if (_publishedResourceTemplates.remove(key)) {
      final pattern = _resourceTemplatePatternByKey.remove(key);
      if (pattern != null) {
        _publishedResourceTemplatePatterns.remove(pattern);
      }
      // dart_mcp has no removeResourceTemplate; registry unregister is enough.
    }
  }
}
