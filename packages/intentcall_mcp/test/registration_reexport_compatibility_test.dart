import 'package:intentcall_core/intentcall_core.dart' as core;
import 'package:intentcall_mcp/intentcall_mcp.dart' as mcp;
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('re-exports core-owned registration types source-compatibly', () async {
    expectMcpToolHandler(_toolHandler);
    expectMcpResourceHandler(_resourceHandler);

    const mcpTool = mcp.ToolRegistration(
      name: 'echo',
      description: 'Echo arguments',
      inputSchema: <String, Object?>{'type': 'object'},
      handler: _toolHandler,
    );
    const mcpResource = mcp.ResourceRegistration(
      uri: 'intentcall://resource/app/state',
      name: 'app_state',
      description: 'App state',
      mimeType: 'application/json',
      handler: _resourceHandler,
    );
    const mcpTemplate = mcp.ResourceTemplateRegistration(
      uriTemplate: 'intentcall://resource/app/{id}',
      name: 'app_resource',
      description: 'App resource',
      mimeType: 'application/json',
      handler: _resourceHandler,
    );

    const core.ToolRegistration coreTool = mcpTool;
    const core.ResourceRegistration coreResource = mcpResource;
    const core.ResourceTemplateRegistration coreTemplate = mcpTemplate;

    expect(coreTool.name, 'echo');
    expect(coreResource.uri, 'intentcall://resource/app/state');
    expect(coreTemplate.uriTemplate, 'intentcall://resource/app/{id}');
    expect(
      await coreTool.handler(const <String, Object?>{}),
      isA<AgentResult>(),
    );
  });

  test(
    'McpPublishAdapter accepts and publishes core-owned registrations',
    () async {
      final registry = core.InMemoryAgentRegistry();
      final publishedTools = <String>[];
      final publishedResources = <String>[];
      final publishedTemplates = <String>[];
      final adapter = mcp.McpPublishAdapter(
        publishTool: (final tool, final impl) {
          publishedTools.add(tool.name);
        },
        unpublishTool: (_) {},
        publishResource: (final resource, final impl) {
          publishedResources.add(resource.uri);
        },
        unpublishResource: (_) {},
        publishResourceTemplate: (final template, final impl) {
          publishedTemplates.add(template.uriTemplate);
        },
      );

      final coreTool = core.ToolRegistration(
        name: 'echo',
        description: 'Echo arguments',
        inputSchema: const <String, Object?>{'type': 'object'},
        handler: (final arguments) async =>
            AgentResult.success(data: arguments),
      );
      final coreResource = core.ResourceRegistration(
        uri: 'intentcall://resource/app/state',
        name: 'app_state',
        description: 'App state',
        mimeType: 'application/json',
        handler: (final uri) async =>
            AgentResult.success(data: <String, Object?>{'uri': uri}),
      );
      final coreTemplate = core.ResourceTemplateRegistration(
        uriTemplate: 'intentcall://resource/app/{id}',
        name: 'app_resource',
        description: 'App resource',
        mimeType: 'application/json',
        handler: (final uri) async =>
            AgentResult.success(data: <String, Object?>{'uri': uri}),
      );

      await adapter.attach(registry);
      adapter
        ..publishCapabilityTool(
          registry: registry,
          capabilityId: 'app',
          registration: coreTool,
          fullName: 'app_echo',
        )
        ..publishCapabilityResource(
          registry: registry,
          capabilityId: 'app',
          registration: coreResource,
        )
        ..publishCapabilityResourceTemplate(
          registry: registry,
          capabilityId: 'app',
          registration: coreTemplate,
        );

      await Future<void>.delayed(Duration.zero);

      expect(publishedTools, contains('app_echo'));
      expect(publishedResources, contains('intentcall://resource/app/state'));
      expect(publishedTemplates, contains('intentcall://resource/app/{id}'));

      await adapter.detach();
    },
  );
}

void expectMcpToolHandler(final mcp.ToolHandler handler) {}

void expectMcpResourceHandler(final mcp.ResourceHandler handler) {}

Future<AgentResult> _toolHandler(final AgentArguments arguments) async =>
    AgentResult.success(data: arguments);

Future<AgentResult> _resourceHandler(final String uri) async =>
    AgentResult.success(data: <String, Object?>{'uri': uri});
