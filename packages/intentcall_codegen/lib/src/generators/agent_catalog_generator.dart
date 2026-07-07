import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
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
  static const _defaultHostBindingField = 'shared';
  static const _handwrittenCatalogPath = 'lib/catalog/handwritten_entries.dart';
  static const _handwrittenCatalogImport =
      '../catalog/handwritten_entries.dart';
  static const _handwrittenCatalogSymbol = 'handwrittenCatalogEntries';

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['generated/agent_catalog.g.dart'],
  };

  bool get _scanExample => options.config['scan_example'] as bool? ?? false;

  String get _hostBindingField =>
      options.config['host_binding_field'] as String? ??
      _defaultHostBindingField;

  @override
  Future<void> build(final BuildStep buildStep) async {
    final outputPath = buildStep.allowedOutputs.single.path;
    final imports = <String>{};
    final entries = <String>[];
    final codegenRegistryKeys = <String>{};

    await for (final input in _toolSources(buildStep)) {
      final library = await buildStep.resolver.libraryFor(input);
      final fileEntries = <String>[];

      for (final element in library.topLevelFunctions) {
        final entry = _catalogEntryForToolElement(element, codegenRegistryKeys);
        if (entry != null) {
          fileEntries.add(entry);
        }
      }

      final libraryReader = LibraryReader(library);
      for (final classElement in libraryReader.classes) {
        for (final method in classElement.methods) {
          if (method.isStatic) {
            continue;
          }
          final entry = _catalogEntryForToolElement(
            method,
            codegenRegistryKeys,
          );
          if (entry != null) {
            fileEntries.add(entry);
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

    final handwrittenAsset = AssetId(
      buildStep.inputId.package,
      _handwrittenCatalogPath,
    );
    final hasHandwritten = await buildStep.canRead(handwrittenAsset);
    if (hasHandwritten) {
      imports.add("import '$_handwrittenCatalogImport';");
      final handwrittenKeys = await _readHandwrittenRegistryKeys(
        buildStep,
        handwrittenAsset,
      );
      final seenHandwrittenKeys = <String>{};
      for (final key in handwrittenKeys) {
        if (codegenRegistryKeys.contains(key)) {
          throw InvalidGenerationSourceError(
            "Duplicate registryKey '$key' in agent catalog — declared in "
            'both @AgentTool codegen and handwritten catalog entries.',
          );
        }
        if (!seenHandwrittenKeys.add(key)) {
          throw InvalidGenerationSourceError(
            "Duplicate registryKey '$key' in handwritten catalog entries.",
          );
        }
      }
    }

    final header =
        '''
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
${imports.join('\n')}
''';

    if (entries.isEmpty && !hasHandwritten) {
      await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
/// Empty catalog — add @AgentTool functions under lib/.
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[];
''');
      return;
    }

    final catalogRows = _catalogRows(entries, hasHandwritten: hasHandwritten);
    await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[
$catalogRows
];
''');
  }

  String? _catalogEntryForToolElement(
    final Element element,
    final Set<String> codegenRegistryKeys,
  ) {
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
      return null;
    }

    if (element is MethodElement) {
      if (element.isStatic) {
        return null;
      }
      final enclosing = element.enclosingElement;
      if (enclosing is! ClassElement) {
        return null;
      }
    } else if (element is! TopLevelFunctionElement) {
      return null;
    }

    final namespace = toolReader.read('namespace').stringValue;
    final name = toolReader.read('name').stringValue;
    final registryKey = '${namespace}_$name';
    if (!codegenRegistryKeys.add(registryKey)) {
      throw InvalidGenerationSourceError(
        "Duplicate registryKey '$registryKey' from @AgentTool declarations.",
        element: element,
      );
    }
    final entryGetter = '${_toCamelCase(name)}CallEntry';
    final entryReference = element is MethodElement
        ? '${(element.enclosingElement! as ClassElement).name}.$_hostBindingField.$entryGetter'
        : entryGetter;
    final projectionLiteral = projectionReader == null
        ? null
        : _projectionLiteral(projectionReader);
    return projectionLiteral == null
        ? "  AgentRegistryCatalogEntry(registryKey: '$registryKey', entry: $entryReference),"
        : "  AgentRegistryCatalogEntry(registryKey: '$registryKey', entry: $entryReference, projection: $projectionLiteral),";
  }

  String _catalogRows(
    final List<String> entries, {
    required final bool hasHandwritten,
  }) {
    if (entries.isEmpty) {
      return '  ...$_handwrittenCatalogSymbol,';
    }
    if (!hasHandwritten) {
      return entries.join('\n');
    }
    return '${entries.join('\n')}\n  ...$_handwrittenCatalogSymbol,';
  }

  Future<List<String>> _readHandwrittenRegistryKeys(
    final BuildStep buildStep,
    final AssetId assetId,
  ) async {
    final library = await buildStep.resolver.libraryFor(assetId);
    TopLevelVariableElement? variable;
    for (final element in library.topLevelVariables) {
      if (element.name == _handwrittenCatalogSymbol) {
        variable = element;
        break;
      }
    }
    if (variable == null) {
      throw InvalidGenerationSourceError(
        '$_handwrittenCatalogPath must export $_handwrittenCatalogSymbol '
        'as List<AgentRegistryCatalogEntry>.',
      );
    }

    final constant = variable.computeConstantValue();
    if (constant != null) {
      final list = constant.toListValue();
      if (list != null) {
        final keys = <String>[];
        for (final item in list) {
          final key = item.getField('registryKey')?.toStringValue();
          if (key != null) {
            keys.add(key);
          }
        }
        return keys;
      }
    }

    final unit = await buildStep.resolver.compilationUnitFor(assetId);
    final keys = <String>[];
    for (final declaration in unit.declarations) {
      if (declaration is! TopLevelVariableDeclaration) {
        continue;
      }
      for (final variableDeclaration in declaration.variables.variables) {
        if (variableDeclaration.name.lexeme != _handwrittenCatalogSymbol) {
          continue;
        }
        final initializer = variableDeclaration.initializer;
        if (initializer != null) {
          _collectRegistryKeysFromExpression(initializer, keys);
        }
      }
    }
    if (keys.isEmpty) {
      throw InvalidGenerationSourceError(
        'Could not read registryKey values from $_handwrittenCatalogSymbol '
        'in $_handwrittenCatalogPath.',
        element: variable,
      );
    }
    return keys;
  }

  void _collectRegistryKeysFromExpression(
    final Expression expression,
    final List<String> keys,
  ) {
    if (expression is ListLiteral) {
      for (final element in expression.elements) {
        if (element is! Expression) {
          continue;
        }
        _collectRegistryKeyFromEntryExpression(element, keys);
      }
      return;
    }
    _collectRegistryKeyFromEntryExpression(expression, keys);
  }

  void _collectRegistryKeyFromEntryExpression(
    final Expression expression,
    final List<String> keys,
  ) {
    final ArgumentList? argumentList = switch (expression) {
      InstanceCreationExpression(:final argumentList) => argumentList,
      MethodInvocation(:final argumentList) => argumentList,
      _ => null,
    };
    if (argumentList == null) {
      return;
    }
    for (final argument in argumentList.arguments) {
      if (argument is! NamedExpression ||
          argument.name.label.name != 'registryKey') {
        continue;
      }
      final value = argument.expression;
      if (value is! StringLiteral || value.stringValue == null) {
        continue;
      }
      keys.add(value.stringValue!);
    }
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
