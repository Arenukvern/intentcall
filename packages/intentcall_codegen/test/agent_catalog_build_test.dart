import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:glob/glob.dart';
import 'package:intentcall_codegen/src/generators/agent_catalog_generator.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

const _package = 'intentcall_codegen';
const _trigger = '$_package|lib/\$lib\$';
const _output = '$_package|lib/generated/agent_catalog.g.dart';

String _fixture(final String path) => File(path).readAsStringSync();

BuilderOptions _options(final Map<String, Object> config) =>
    BuilderOptions(config);

bool _isCatalogBuildInput(final String id) =>
    id == _trigger || id.startsWith('$_package|test/fixtures/catalog/');

Map<String, String> _catalogAssets(final Map<String, String> fixtures) => {
  for (final entry in fixtures.entries) '$_package|${entry.key}': entry.value,
};

Future<TestReaderWriter> _readerWriterWithAllSources(
  final PackageConfig packageConfig,
) async {
  final assetReader = PackageAssetReader(packageConfig, _package);
  final readerWriter = TestReaderWriter(rootPackage: _package);
  for (final package in packageConfig.packages) {
    await for (final id in assetReader.findAssets(
      Glob('**'),
      package: package.name,
    )) {
      if (id.path.startsWith('.dart_tool/build/asset_graph.json')) {
        continue;
      }
      readerWriter.testing.writeBytes(id, await assetReader.readAsBytes(id));
    }
  }
  return readerWriter;
}

void main() {
  late PackageConfig packageConfig;
  late TestReaderWriter readerWriter;

  setUpAll(() async {
    final config = await findPackageConfig(Directory.current);
    if (config == null) {
      throw StateError('Could not find package config for tests.');
    }
    packageConfig = config;
    readerWriter = await _readerWriterWithAllSources(packageConfig);
  });

  Future<void> runCatalogBuilder({
    required final AgentCatalogGenerator generator,
    required final Map<String, String> fixtures,
    required final Object outputMatcher,
  }) async {
    await testBuilder(
      generator,
      _catalogAssets(fixtures),
      isInput: _isCatalogBuildInput,
      packageConfig: packageConfig,
      readerWriter: readerWriter,
      outputs: {_output: decodedMatches(outputMatcher)},
    );
  }

  group('AgentCatalogGenerator', () {
    test('aggregates @AgentTool from .g.dart parent', () async {
      await runCatalogBuilder(
        generator: AgentCatalogGenerator(
          _options({
            'tool_part_globs': ['test/fixtures/catalog/**.g.dart'],
            'tool_exclude_globs': <String>[],
          }),
        ),
        fixtures: {
          'test/fixtures/catalog/top_level_tool.dart': _fixture(
            'test/fixtures/catalog/top_level_tool.dart',
          ),
          'test/fixtures/catalog/top_level_tool.g.dart': _fixture(
            'test/fixtures/catalog/top_level_tool.g.dart',
          ),
        },
        outputMatcher: allOf(
          contains('app_catalog_ping'),
          contains('catalogPingCallEntry'),
        ),
      );
    });

    test('discovers @AgentCatalog', () async {
      expect(
        _fixture('test/fixtures/catalog/agent_catalog_annotated.dart'),
        contains('app_sup_a'),
      );
      await runCatalogBuilder(
        generator: AgentCatalogGenerator(
          _options({
            'tool_globs': ['test/fixtures/catalog/**.dart'],
            'tool_exclude_globs': <String>[],
          }),
        ),
        fixtures: {
          'test/fixtures/catalog/agent_catalog_annotated.dart': _fixture(
            'test/fixtures/catalog/agent_catalog_annotated.dart',
          ),
        },
        outputMatcher: allOf(
          contains('...supplementCatalogEntries,'),
          contains(
            "import '../../test/fixtures/catalog/agent_catalog_annotated.dart';",
          ),
        ),
      );
    });

    test('unannotated catalog list omitted', () async {
      await runCatalogBuilder(
        generator: AgentCatalogGenerator(_options({})),
        fixtures: {
          'test/fixtures/catalog/unannotated_catalog_list.dart': _fixture(
            'test/fixtures/catalog/unannotated_catalog_list.dart',
          ),
        },
        outputMatcher: allOf(
          isNot(contains('app_wrong_a')),
          isNot(contains('...unannotatedCatalogEntries,')),
        ),
      );
    });
  });
}
