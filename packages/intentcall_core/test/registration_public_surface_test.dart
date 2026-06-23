import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('exports neutral tool registration vocabulary', () async {
    expectCoreToolHandler(_toolHandler);
    const registration = ToolRegistration(
      name: 'echo',
      description: 'Echo arguments',
      inputSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      },
      handler: _toolHandler,
    );

    expect(registration.name, 'echo');
    expect(
      await registration.handler(const <String, Object?>{}),
      isA<AgentResult>(),
    );
  });

  test('exports neutral resource registration vocabulary', () async {
    expectCoreResourceHandler(_resourceHandler);
    const resource = ResourceRegistration(
      uri: 'intentcall://resource/app/state',
      name: 'app_state',
      description: 'App state',
      mimeType: 'application/json',
      handler: _resourceHandler,
    );
    const template = ResourceTemplateRegistration(
      uriTemplate: 'intentcall://resource/app/{id}',
      name: 'app_resource',
      description: 'App resource',
      mimeType: 'application/json',
      handler: _resourceHandler,
    );

    expect(resource.mimeType, 'application/json');
    expect(template.uriTemplate, contains('{id}'));
    expect(
      await template.handler('intentcall://resource/app/1'),
      isA<AgentResult>(),
    );
  });
}

void expectCoreToolHandler(final ToolHandler handler) {}

void expectCoreResourceHandler(final ResourceHandler handler) {}

Future<AgentResult> _toolHandler(final AgentArguments arguments) async =>
    AgentResult.success(data: arguments);

Future<AgentResult> _resourceHandler(final String uri) async =>
    AgentResult.success(data: <String, Object?>{'uri': uri});
