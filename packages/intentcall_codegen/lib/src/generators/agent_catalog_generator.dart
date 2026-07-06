import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../agent_projection.dart';
import '../agent_tool.dart';

/// Emits `lib/generated/agent_catalog.g.dart` listing all tool call entries.
class AgentCatalogGenerator implements Builder {
  AgentCatalogGenerator(this.options);

  final BuilderOptions options;

  static const _toolChecker = TypeChecker.typeNamed(AgentTool);
  static const _projectionChecker = TypeChecker.typeNamed(AgentProjection);

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['generated/agent_catalog.g.dart'],
  };

  bool get _scanExample => options.config['scan_example'] as bool? ?? false;

  @override
  Future<void> build(final BuildStep buildStep) async {
    final outputPath = buildStep.allowedOutputs.single.path;
    final imports = <String>{};
    final entries = <String>[];

    await for (final input in _toolSources(buildStep)) {
      final library = await buildStep.resolver.libraryFor(input);
      final fileEntries = <String>[];

      for (final element in library.topLevelFunctions) {
        ConstantReader? toolReader;
        ConstantReader? projectionReader;
        for (final annotation in element.metadata.annotations) {
          final reader = ConstantReader(annotation.computeConstantValue());
          if (!reader.isNull && reader.instanceOf(_toolChecker)) {
            toolReader = reader;
          }
          if (!reader.isNull && reader.instanceOf(_projectionChecker)) {
            projectionReader = reader;
          }
        }
        if (toolReader == null) {
          continue;
        }
        final namespace = toolReader.read('namespace').stringValue;
        final name = toolReader.read('name').stringValue;
        final registryKey = '${namespace}_$name';
        final entryGetter = '${_toCamelCase(name)}CallEntry';
        final projectionLiteral = projectionReader == null
            ? null
            : _projectionLiteral(projectionReader);
        fileEntries.add(
          projectionLiteral == null
              ? "  AgentRegistryCatalogEntry(registryKey: '$registryKey', entry: $entryGetter),"
              : "  AgentRegistryCatalogEntry(registryKey: '$registryKey', entry: $entryGetter, projection: $projectionLiteral),",
        );
      }

      if (fileEntries.isEmpty) {
        continue;
      }

      final relative = p
          .relative(input.path, from: p.dirname(outputPath))
          .replaceAll(r'\', '/');
      imports.add("import '$relative';");
      entries.addAll(fileEntries);
    }

    final header =
        '''
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
${imports.join('\n')}
''';

    if (entries.isEmpty) {
      await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
/// Empty catalog — add @AgentTool functions under lib/.
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[];
''');
      return;
    }

    await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[
${entries.join('\n')}
];
''');
  }

  Stream<AssetId> _toolSources(final BuildStep buildStep) async* {
    final patterns = <String>['lib/**.dart'];
    if (_scanExample) {
      patterns.add('example/**.dart');
    }
    for (final pattern in patterns) {
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

  String _projectionLiteral(final ConstantReader reader) {
    final dispatchName = reader.read('dispatchMode').stringValue;
    final surfacesRaw = reader.read('surfaces').mapValue;
    final surfaceEntries = <String>[];
    for (final entry in surfacesRaw.entries) {
      final key = entry.key?.toStringValue();
      final value = entry.value?.toBoolValue();
      if (key == null || value == null) {
        continue;
      }
      surfaceEntries.add(
        'AgentManifestSurface.${_surfaceEnumName(key)}: $value',
      );
    }
    final surfacesBlock = surfaceEntries.isEmpty
        ? 'const <AgentManifestSurface, bool>{}'
        : '<AgentManifestSurface, bool>{${surfaceEntries.join(', ')}}';
    return '''
EntryProjection(
  dispatchMode: AgentManifestDispatchMode.$dispatchName,
  surfaces: $surfacesBlock,
)''';
  }

  String _surfaceEnumName(final String key) {
    const dottedToEnum = <String, String>{
      'web.webMcp': 'webMcp',
      'web.manifestShortcuts': 'webManifestShortcuts',
      'web.protocolHandlers': 'webProtocolHandlers',
      'apple.appShortcuts': 'appleAppShortcuts',
      'android.shortcuts': 'androidShortcuts',
      'windows.protocolActivation': 'windowsProtocolActivation',
      'windows.msixProtocol': 'windowsMsixProtocol',
      'linux.schemeHandler': 'linuxSchemeHandler',
    };
    return dottedToEnum[key] ?? key;
  }

  String _toCamelCase(final String value) {
    if (value.isEmpty) {
      return value;
    }
    final parts = value.split('_');
    final first = parts.first;
    final rest = parts.skip(1).map((final part) {
      if (part.isEmpty) {
        return part;
      }
      return part[0].toUpperCase() + part.substring(1);
    });
    return first + rest.join();
  }
}
