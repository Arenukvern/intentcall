import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:intentcall_codegen/src/generators/agent_tool_generator.dart';
import 'package:package_config/package_config.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

const _package = 'intentcall_codegen';

class _FakeBuildStep implements BuildStep {
  _FakeBuildStep(this.inputId);

  @override
  final AssetId inputId;

  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

void main() {
  late PackageConfig packageConfig;
  final generator = AgentToolGenerator();

  setUpAll(() async {
    final config = await findPackageConfig(Directory.current);
    if (config == null) {
      throw StateError('Could not find package config for tests.');
    }
    packageConfig = config;
  });

  Future<String> generateFixture(final String fixturePath) async =>
      resolveSources(
        {'$_package|$fixturePath': useAssetReader},
        (final resolver) async {
          final library = await resolver.libraryFor(
            AssetId(_package, fixturePath),
          );
          return generator.generate(
            LibraryReader(library),
            _FakeBuildStep(AssetId(_package, fixturePath)),
          );
        },
        packageConfig: packageConfig,
        readAllSourcesFromFilesystem: true,
      );

  Future<String> generateFixtureExpectingError(final String fixturePath) async {
    try {
      await generateFixture(fixturePath);
    } on InvalidGenerationSourceError catch (error) {
      return error.message;
    }
    return '';
  }

  test(
    'instance @AgentTool emits extension getter with this-bound handler',
    () async {
      final output = await generateFixture(
        'test/fixtures/host_instance_tool.dart',
      );

      expect(
        output,
        contains('extension DemoHostToolsAgentCodegen on DemoHostTools'),
      );
      expect(output, contains('AgentCallEntry get demoInboxCallEntry'));
      expect(output, contains('return await inbox('));
      expect(
        output,
        contains('DemoHostTools.shared.demoInboxCallEntry.toRegistration()'),
      );
      expect(output, isNot(contains('Function.apply')));
      expect(output, isNot(contains('DemoHostTools.shared.inbox(')));
    },
  );

  test('instance @AgentTool without host binding field is rejected', () async {
    final message = await generateFixtureExpectingError(
      'test/fixtures/instance_without_host_tool.dart',
    );

    expect(message, contains("require a static host binding field 'shared'"));
  });

  test('static method @AgentTool on class is rejected', () async {
    final message = await generateFixtureExpectingError(
      'test/fixtures/static_method_tool.dart',
    );

    expect(message, contains('use top-level @AgentTool or handwritten entry'));
  });
}
