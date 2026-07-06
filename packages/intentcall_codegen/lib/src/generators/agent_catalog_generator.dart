import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../agent_tool.dart';

/// Emits `lib/generated/agent_catalog.g.dart` listing all tool call entries.
class AgentCatalogGenerator implements Builder {
  static const _toolChecker = TypeChecker.typeNamed(AgentTool);

  @override
  final Map<String, List<String>> buildExtensions = const {
    r'$lib$': ['generated/agent_catalog.g.dart'],
  };

  @override
  Future<void> build(final BuildStep buildStep) async {
    final outputPath = buildStep.allowedOutputs.single.path;
    final imports = <String>{};
    final entries = <String>[];

    await for (final input in _toolSources(buildStep)) {
      final library = await buildStep.resolver.libraryFor(input);
      final fileEntries = <String>[];

      for (final element in library.topLevelFunctions) {
        for (final annotation in element.metadata.annotations) {
          final reader = ConstantReader(annotation.computeConstantValue());
          if (!reader.isNull && reader.instanceOf(_toolChecker)) {
            final namespace = reader.read('namespace').stringValue;
            final name = reader.read('name').stringValue;
            final registryKey = '${namespace}_$name';
            final entryGetter = '${_toCamelCase(name)}CallEntry';
            fileEntries.add(
              "  AgentRegistryCatalogEntry(registryKey: '$registryKey', entry: $entryGetter),",
            );
          }
        }
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
/// Empty catalog — add @AgentTool functions under lib/ or example/.
const List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[];
''');
      return;
    }

    await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
const List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[
${entries.join('\n')}
];
''');
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
