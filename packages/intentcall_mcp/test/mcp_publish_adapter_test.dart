import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test(
    'McpPublishAdapter hot-syncs resource on IntentRegistered event',
    () async {
      final registry = InMemoryAgentRegistry();
      final publishedResources =
          <
            String,
            FutureOr<ReadResourceResult> Function(ReadResourceRequest)
          >{};
      final unpublished = <String>[];
      const uri = 'visual://localhost/app/errors';

      final adapter = McpPublishAdapter(
        publishTool: (_, final _) {},
        unpublishTool: (_) {},
        publishResource: (final resource, final impl) {
          publishedResources[resource.uri] = impl;
        },
        unpublishResource: unpublished.add,
      );

      await adapter.attach(registry);
      expect(publishedResources, isEmpty);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'errors',
            description: 'errors resource',
            kind: AgentIntentKind.resource,
            inputSchema: const <String, Object?>{'type': 'object'},
            resourceUri: uri,
            mimeType: 'application/json',
          ),
          execute: (_) async => AgentResult.success(
            data: const <String, Object?>{
              'contents': [
                <String, Object?>{
                  'type': 'text',
                  'text': '{"count":0}',
                  'mimeType': 'application/json',
                },
              ],
            },
          ),
        ),
        qualifiedNameOverride: uri,
      );

      await Future<void>.delayed(Duration.zero);
      expect(publishedResources, contains(uri));

      final read = await publishedResources[uri]!(
        ReadResourceRequest(uri: uri),
      );
      expect(read.contents, isNotEmpty);
      final text = (read.contents.first as TextResourceContents).text;
      expect(text, '{"count":0}');

      registry.unregister(uri);
      await Future<void>.delayed(Duration.zero);
      expect(unpublished, contains(uri));

      await adapter.detach();
    },
  );

  test(
    'McpPublishAdapter publishes static resources as query-tolerant templates',
    () async {
      final registry = InMemoryAgentRegistry();
      final publishedResources =
          <
            String,
            FutureOr<ReadResourceResult> Function(ReadResourceRequest)
          >{};
      final publishedTemplates =
          <
            String,
            FutureOr<ReadResourceResult?> Function(ReadResourceRequest)
          >{};
      const uri = 'visual://localhost/view/details';

      final adapter = McpPublishAdapter(
        publishTool: (_, final _) {},
        unpublishTool: (_) {},
        publishResource: (final resource, final impl) {
          publishedResources[resource.uri] = impl;
        },
        unpublishResource: (_) {},
        publishResourceTemplate: (final template, final impl) {
          publishedTemplates[template.uriTemplate] = impl;
        },
      );

      await adapter.attach(registry);

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'visual',
            name: 'view_details',
            description: 'view details',
            kind: AgentIntentKind.resource,
            inputSchema: const <String, Object?>{'type': 'object'},
            resourceUri: uri,
            mimeType: 'application/json',
          ),
          execute: (final invocation) async => AgentResult.success(
            data: <String, Object?>{
              'contents': [
                <String, Object?>{
                  'type': 'text',
                  'text': '{"uri":"${invocation.arguments['uri']}"}',
                  'mimeType': 'application/json',
                },
              ],
            },
          ),
        ),
        qualifiedNameOverride: uri,
      );

      await Future<void>.delayed(Duration.zero);
      expect(publishedResources, contains(uri));
      expect(publishedTemplates, contains(uri));

      final queryRead = await publishedTemplates[uri]!(
        ReadResourceRequest(uri: '$uri?uri=ws%3A%2F%2F127.0.0.1%2Fws'),
      );
      expect(queryRead, isNotNull);
      final text = (queryRead!.contents.first as TextResourceContents).text;
      expect(text, contains('$uri?uri=ws%3A%2F%2F127.0.0.1%2Fws'));

      await adapter.detach();
    },
  );

  test(
    'McpPublishAdapter de-duplicates resource templates by URI pattern',
    () async {
      final registry = InMemoryAgentRegistry();
      final publishedResources =
          <
            String,
            FutureOr<ReadResourceResult> Function(ReadResourceRequest)
          >{};
      final publishedTemplates = <String>[];
      const uri = 'intentcall://resource/app/state';

      final adapter = McpPublishAdapter(
        publishTool: (_, final _) {},
        unpublishTool: (_) {},
        publishResource: (final resource, final impl) {
          publishedResources[resource.uri] = impl;
        },
        unpublishResource: (_) {},
        publishResourceTemplate: (final template, final impl) {
          publishedTemplates.add(template.uriTemplate);
        },
      );

      await adapter.attach(registry);
      adapter.publishCapabilityResourceTemplate(
        registry: registry,
        capabilityId: 'app',
        registration: ResourceTemplateRegistration(
          uriTemplate: uri,
          name: 'app_state',
          description: 'App state',
          mimeType: 'application/json',
          handler: (_) async => AgentResult.success(),
        ),
      );

      registry.register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'dynamic',
            name: 'app_state',
            description: 'App state mirrored through dynamic discovery',
            kind: AgentIntentKind.resource,
            inputSchema: const <String, Object?>{'type': 'object'},
            resourceUri: uri,
            mimeType: 'application/json',
          ),
          execute: (_) async => AgentResult.success(
            data: const <String, Object?>{
              'contents': [
                <String, Object?>{
                  'type': 'text',
                  'text': '{}',
                  'mimeType': 'application/json',
                },
              ],
            },
          ),
        ),
        qualifiedNameOverride: 'dynamic_app_state',
      );

      await Future<void>.delayed(Duration.zero);
      expect(publishedTemplates, [uri]);
      expect(publishedResources, contains(uri));

      await adapter.detach();
    },
  );

  test('McpPublishAdapter detach does not unregister source intents', () async {
    final registry = InMemoryAgentRegistry()
      ..register(
        RegisteredAgentIntent(
          descriptor: AgentIntentDescriptor(
            namespace: 'app',
            name: 'hello',
            description: 'hello',
            kind: AgentIntentKind.tool,
            inputSchema: const <String, Object?>{'type': 'object'},
          ),
          execute: (_) async => AgentResult.success(),
        ),
      );
    final unpublished = <String>[];
    final adapter = McpPublishAdapter(
      publishTool: (_, final _) {},
      unpublishTool: unpublished.add,
    );

    await adapter.attach(registry);
    await adapter.detach();

    expect(unpublished, contains('app_hello'));
    expect(registry.get('app_hello'), isNotNull);
  });
}
