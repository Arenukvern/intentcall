import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:source_gen/source_gen.dart';

import '../agent_projection.dart';
import '../agent_tool.dart';
import 'agent_tool_generator.dart';

/// Writes `web/agent_manifest.json` from `@AgentTool` and `@AgentProjection`.
class AgentManifestAssetGenerator implements Builder {
  AgentManifestAssetGenerator(this.options);

  final BuilderOptions options;

  static const _toolChecker = TypeChecker.typeNamed(AgentTool);
  static const _projectionChecker = TypeChecker.typeNamed(AgentProjection);

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [
      options.config['manifest_output'] as String? ?? 'web/agent_manifest.json',
    ],
  };

  @override
  Future<void> build(final BuildStep buildStep) async {
    final catalog = <AgentRegistryCatalogEntry>[];
    final overlays = <String, EntryProjection>{};
    final toolGen = AgentToolGenerator();

    await for (final input in _toolSources(buildStep)) {
      final library = await buildStep.resolver.libraryFor(input);
      for (final element in library.topLevelFunctions) {
        ConstantReader? toolReader;
        for (final annotation in element.metadata.annotations) {
          final reader = ConstantReader(annotation.computeConstantValue());
          if (!reader.isNull && reader.instanceOf(_toolChecker)) {
            toolReader = reader;
          }
          if (!reader.isNull && reader.instanceOf(_projectionChecker)) {
            final namespace = _toolNamespace(element, toolReader);
            final name = _toolName(element, toolReader);
            if (namespace != null && name != null) {
              final qualified = '${namespace}_$name';
              overlays[qualified] = _entryProjectionFromReader(reader);
            }
          }
        }
        if (toolReader == null) {
          continue;
        }
        final namespace = toolReader.read('namespace').stringValue;
        final name = toolReader.read('name').stringValue;
        final description = toolReader.read('description').stringValue;
        final schema = toolGen.inputSchemaMapFor(element);
        catalog.add(
          AgentRegistryCatalogEntry(
            registryKey: '${namespace}_$name',
            descriptor: AgentIntentDescriptor(
              namespace: namespace,
              name: name,
              description: description,
              kind: AgentIntentKind.tool,
              inputSchema: schema,
            ),
          ),
        );
      }
    }

    const merger = ManifestMerger();
    final policy = ProjectionPolicy(overlays: overlays);
    final protocolScheme = options.config['protocol_scheme'] as String?;
    final manifest = merger.mergeManifest(
      catalog: catalog,
      policy: policy,
      protocolScheme: protocolScheme,
    );
    await buildStep.writeAsString(
      buildStep.allowedOutputs.single,
      merger.encodeManifest(manifest),
    );
  }

  Stream<AssetId> _toolSources(final BuildStep buildStep) async* {
    for (final pattern in <String>['lib/**.dart', 'example/**.dart']) {
      await for (final input in buildStep.findAssets(Glob(pattern))) {
        if (_isInternalSource(input.path)) {
          continue;
        }
        yield input;
      }
    }
  }

  bool _isInternalSource(final String path) =>
      path.contains('.g.dart') ||
      path.contains('generated/') ||
      path.contains('lib/src/') ||
      path.endsWith('lib/builder.dart') ||
      path.endsWith('lib/intentcall_codegen.dart');

  String? _toolNamespace(
    final TopLevelFunctionElement element,
    final ConstantReader? toolReader,
  ) => toolReader?.read('namespace').stringValue;

  String? _toolName(
    final TopLevelFunctionElement element,
    final ConstantReader? toolReader,
  ) => toolReader?.read('name').stringValue;

  EntryProjection _entryProjectionFromReader(final ConstantReader reader) {
    final dispatchName = reader.read('dispatchMode').stringValue;
    final surfacesRaw = reader.read('surfaces').mapValue;
    final surfaces = <AgentManifestSurface, bool>{};
    for (final entry in surfacesRaw.entries) {
      final key = entry.key?.toStringValue();
      final value = entry.value?.toBoolValue();
      if (key == null || value == null) {
        continue;
      }
      final surface = lookupAgentManifestSurface(key);
      if (surface != null) {
        surfaces[surface] = value;
      }
    }
    return EntryProjection(
      dispatchMode: AgentManifestDispatchMode.values.byName(dispatchName),
      surfaces: surfaces,
    );
  }
}
