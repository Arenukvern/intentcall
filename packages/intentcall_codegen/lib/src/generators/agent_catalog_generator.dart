import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../agent_catalog.dart';
import '../agent_projection.dart';
import '../agent_tool.dart';
import 'agent_tool_generator.dart';

/// Emits `lib/generated/agent_catalog.g.dart` by merging three catalog sources:
///
/// 1. **`@AgentTool`** — rows from generated `*.g.dart` parts (`tool_part_globs`).
/// 2. **`@AgentCatalog`** — top-level or static `List<AgentRegistryCatalogEntry>`
///    discovered via `tool_globs` (default `lib/**.dart`). Static host lists
///    spread as `HostClass.catalogSymbol`.
/// 3. Empty catalog stub when neither source is present.
///
/// Configure via `intentcall_codegen|agent_catalog` in `build.yaml`:
/// `tool_part_globs`, `tool_globs`, `tool_exclude_globs`, `host_binding_field`.
///
/// See [AgentCatalog] and [ADR 0021](https://github.com/Arenukvern/intentcall/blob/main/docs/decisions/0021-agent-catalog-annotation.md).
class AgentCatalogGenerator implements Builder {
  AgentCatalogGenerator(this.options);

  final BuilderOptions options;

  static const _toolChecker = TypeChecker.typeNamed(AgentTool);
  static const _projectionChecker = TypeChecker.typeNamed(AgentProjection);
  static const _agentCatalogChecker = TypeChecker.typeNamed(AgentCatalog);
  static const _defaultHostBindingField = 'shared';

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['generated/agent_catalog.g.dart'],
  };

  List<String> get _toolGlobs =>
      (options.config['tool_globs'] as List?)?.cast<String>() ??
      const ['lib/**.dart'];

  List<String> get _toolExcludeGlobs =>
      (options.config['tool_exclude_globs'] as List?)?.cast<String>() ??
      const ['lib/**.g.dart', 'lib/generated/**'];

  List<String> get _toolPartGlobs =>
      (options.config['tool_part_globs'] as List?)?.cast<String>() ??
      const ['lib/**.g.dart'];

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

      imports.add("import '${_importForAsset(input.path, outputPath)}';");
      entries.addAll(fileEntries);
    }

    final knownRegistryKeys = <String>{...codegenRegistryKeys};

    final agentCatalogLists = await _discoverAgentCatalogLists(
      buildStep,
      outputPath,
    );
    final seenAgentCatalogSymbols = <String>{};
    for (final catalogList in agentCatalogLists) {
      if (!seenAgentCatalogSymbols.add(catalogList.symbolName)) {
        throw InvalidGenerationSourceError(
          "Duplicate @AgentCatalog symbol '${catalogList.symbolName}' "
          'in agent catalog — each annotated list must use a unique name.',
        );
      }
      imports.add("import '${catalogList.importPath}';");
      final catalogKeys = await _readCatalogListRegistryKeys(
        buildStep,
        catalogList.assetId,
        catalogList.symbolName,
      );
      _assertUniqueRegistryKeys(
        knownKeys: knownRegistryKeys,
        newKeys: catalogKeys,
        sourceLabel:
            '@AgentCatalog ${catalogList.symbolName} '
            'in ${catalogList.assetId.path}',
        conflictWithCodegen: true,
      );
    }

    final header =
        '''
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
${imports.join('\n')}
''';

    if (entries.isEmpty && agentCatalogLists.isEmpty) {
      await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
/// Empty catalog — add @AgentTool functions under lib/.
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[];
''');
      return;
    }

    final catalogRows = _catalogRows(
      entries,
      agentCatalogSymbols: agentCatalogLists
          .map((final list) => list.symbolName)
          .toList(),
    );
    await buildStep.writeAsString(buildStep.allowedOutputs.single, '''
$header
final List<AgentRegistryCatalogEntry> agentCatalogEntries =
    <AgentRegistryCatalogEntry>[
$catalogRows
];
''');
  }

  String _importForAsset(final String assetPath, final String outputPath) =>
      p.relative(assetPath, from: p.dirname(outputPath)).replaceAll(r'\', '/');

  void _assertUniqueRegistryKeys({
    required final Set<String> knownKeys,
    required final List<String> newKeys,
    required final String sourceLabel,
    required final bool conflictWithCodegen,
  }) {
    final seen = <String>{};
    for (final key in newKeys) {
      if (knownKeys.contains(key)) {
        throw InvalidGenerationSourceError(
          conflictWithCodegen
              ? "Duplicate registryKey '$key' in agent catalog — declared in "
                    'both @AgentTool codegen and $sourceLabel.'
              : "Duplicate registryKey '$key' in agent catalog — "
                    'declared in $sourceLabel.',
        );
      }
      if (!seen.add(key)) {
        throw InvalidGenerationSourceError(
          "Duplicate registryKey '$key' in $sourceLabel.",
        );
      }
      knownKeys.add(key);
    }
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
    final description = toolReader.read('description').stringValue;
    final projectionLiteral = projectionReader == null
        ? null
        : _projectionLiteral(projectionReader);

    if (element is MethodElement) {
      final classElement = element.enclosingElement! as ClassElement;
      if (_hasBindingField(classElement, _hostBindingField)) {
        final entryReference =
            '${classElement.name}.$_hostBindingField.$entryGetter';
        return _formatCatalogRow(
          registryKey: registryKey,
          entryReference: entryReference,
          projectionLiteral: projectionLiteral,
        );
      }
      final descriptorLiteral = _descriptorLiteralForExecutable(
        element,
        namespace: namespace,
        name: name,
        description: description,
      );
      return _formatCatalogRow(
        registryKey: registryKey,
        descriptorLiteral: descriptorLiteral,
        projectionLiteral: projectionLiteral,
      );
    }

    return _formatCatalogRow(
      registryKey: registryKey,
      entryReference: entryGetter,
      projectionLiteral: projectionLiteral,
    );
  }

  String _formatCatalogRow({
    required final String registryKey,
    final String? entryReference,
    final String? descriptorLiteral,
    final String? projectionLiteral,
  }) {
    assert(entryReference != null || descriptorLiteral != null);
    final target = entryReference != null
        ? 'entry: $entryReference'
        : 'descriptor: $descriptorLiteral';
    if (projectionLiteral == null) {
      return "  AgentRegistryCatalogEntry(registryKey: '$registryKey', $target),";
    }
    return "  AgentRegistryCatalogEntry(registryKey: '$registryKey', $target, projection: $projectionLiteral),";
  }

  bool _hasBindingField(
    final ClassElement classElement,
    final String bindingField,
  ) {
    for (final field in classElement.fields) {
      if (field.isStatic && field.name == bindingField) {
        return true;
      }
    }
    return false;
  }

  String _descriptorLiteralForExecutable(
    final ExecutableElement executable, {
    required final String namespace,
    required final String name,
    required final String description,
  }) {
    final schemaGenerator = AgentToolGenerator(options);
    final schemaMap = schemaGenerator.inputSchemaMapFor(executable);
    final schemaLiteral = _formatInputSchemaConst(schemaMap);
    return '''AgentIntentDescriptor(
    namespace: ${_literalString(namespace)},
    name: ${_literalString(name)},
    description: ${_literalString(description)},
    kind: AgentIntentKind.tool,
    inputSchema: const $schemaLiteral,
  )''';
  }

  String _formatInputSchemaConst(final Map<String, Object?> schema) {
    final properties = schema['properties']! as Map<String, Object?>;
    final required = (schema['required']! as List<Object?>).cast<String>();
    final propertyLines = properties.entries
        .map(
          (final entry) =>
              "      ${_literalString(entry.key)}: <String, Object?>{'type': ${_literalString((entry.value! as Map)['type'] as String)}, 'description': ${_literalString((entry.value! as Map)['description'] as String)}},",
        )
        .join('\n');
    final requiredLines = required.map(_literalString).join(', ');
    return '''<String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
$propertyLines
    },
    'required': <String>[$requiredLines],
  }''';
  }

  String _literalString(final String value) =>
      "'${value.replaceAll("'", r"\'")}'";

  String _catalogRows(
    final List<String> entries, {
    required final List<String> agentCatalogSymbols,
  }) {
    final lines = <String>[];
    if (entries.isNotEmpty) {
      lines.add(entries.join('\n'));
    }
    for (final symbol in agentCatalogSymbols) {
      lines.add('  ...$symbol,');
    }
    return lines.join('\n');
  }

  Future<List<_CatalogSpread>> _discoverAgentCatalogLists(
    final BuildStep buildStep,
    final String outputPath,
  ) async {
    final supplements = <_CatalogSpread>[];
    for (final pattern in _toolGlobs) {
      await for (final input in buildStep.findAssets(Glob(pattern))) {
        if (input.path.endsWith('.g.dart')) {
          continue;
        }
        if (_isExcluded(input.path) || _isInternalSource(input.path)) {
          continue;
        }

        final library = await buildStep.resolver.libraryFor(input);
        final libraryReader = LibraryReader(library);
        for (final variable in library.topLevelVariables) {
          _addAgentCatalogSpread(
            spreads: supplements,
            element: variable,
            assetId: input,
            outputPath: outputPath,
            symbolName: variable.name!,
          );
        }
        for (final classElement in libraryReader.classes) {
          for (final field in classElement.fields) {
            if (!field.isStatic) {
              continue;
            }
            _addAgentCatalogSpread(
              spreads: supplements,
              element: field,
              assetId: input,
              outputPath: outputPath,
              symbolName: '${classElement.name}.${field.name}',
            );
          }
        }
      }
    }
    supplements.sort((final a, final b) {
      final pathCompare = a.assetId.path.compareTo(b.assetId.path);
      if (pathCompare != 0) {
        return pathCompare;
      }
      return a.symbolName.compareTo(b.symbolName);
    });
    return supplements;
  }

  void _addAgentCatalogSpread({
    required final List<_CatalogSpread> spreads,
    required final Element element,
    required final AssetId assetId,
    required final String outputPath,
    required final String symbolName,
  }) {
    if (!_hasAgentCatalogAnnotation(element)) {
      return;
    }
    final type = switch (element) {
      TopLevelVariableElement(:final type) => type,
      FieldElement(:final type) => type,
      _ => null,
    };
    if (type == null || !_isCatalogEntryListType(type)) {
      throw InvalidGenerationSourceError(
        '@AgentCatalog on $symbolName must be '
        'List<AgentRegistryCatalogEntry>.',
        element: element,
      );
    }
    spreads.add(
      _CatalogSpread(
        assetId: assetId,
        symbolName: symbolName,
        importPath: _importForAsset(assetId.path, outputPath),
      ),
    );
  }

  bool _hasAgentCatalogAnnotation(final Element element) {
    for (final annotation in element.metadata.annotations) {
      final reader = ConstantReader(annotation.computeConstantValue());
      if (!reader.isNull && reader.instanceOf(_agentCatalogChecker)) {
        return true;
      }
    }
    return false;
  }

  bool _isCatalogEntryListType(final DartType type) {
    if (type is! InterfaceType) {
      return false;
    }
    if (type.element.name != 'List' || type.typeArguments.length != 1) {
      return false;
    }
    final argument = type.typeArguments.single;
    if (argument is! InterfaceType) {
      return false;
    }
    return argument.element.name == 'AgentRegistryCatalogEntry';
  }

  Future<List<String>> _readCatalogListRegistryKeys(
    final BuildStep buildStep,
    final AssetId assetId,
    final String symbolName,
  ) async {
    final library = await buildStep.resolver.libraryFor(assetId);
    final qualified = _parseCatalogSymbolName(symbolName);
    final Element? element = switch (qualified) {
      _TopLevelCatalogSymbol(:final name) => _findTopLevelCatalogVariable(
        library,
        name,
      ),
      _StaticCatalogSymbol(:final className, :final fieldName) =>
        _findStaticCatalogField(library, className, fieldName),
    };
    if (element == null) {
      throw InvalidGenerationSourceError(
        '${assetId.path} must export $symbolName '
        'as List<AgentRegistryCatalogEntry>.',
      );
    }

    if (element is VariableElement) {
      final constant = element.computeConstantValue();
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
    }

    final unit = await buildStep.resolver.compilationUnitFor(assetId);
    final keys = <String>[];
    switch (qualified) {
      case _TopLevelCatalogSymbol(:final name):
        for (final declaration in unit.declarations) {
          if (declaration is! TopLevelVariableDeclaration) {
            continue;
          }
          for (final variableDeclaration in declaration.variables.variables) {
            if (variableDeclaration.name.lexeme != name) {
              continue;
            }
            final initializer = variableDeclaration.initializer;
            if (initializer != null) {
              _collectRegistryKeysFromExpression(initializer, keys);
            }
          }
        }
      case _StaticCatalogSymbol(:final className, :final fieldName):
        for (final declaration in unit.declarations) {
          if (declaration is! ClassDeclaration ||
              declaration.name.lexeme != className) {
            continue;
          }
          for (final member in declaration.members) {
            if (member is! FieldDeclaration) {
              continue;
            }
            for (final variableDeclaration in member.fields.variables) {
              if (variableDeclaration.name.lexeme != fieldName) {
                continue;
              }
              final initializer = variableDeclaration.initializer;
              if (initializer != null) {
                _collectRegistryKeysFromExpression(initializer, keys);
              }
            }
          }
        }
    }
    if (keys.isEmpty) {
      throw InvalidGenerationSourceError(
        'Could not read registryKey values from $symbolName '
        'in ${assetId.path}.',
        element: element,
      );
    }
    return keys;
  }

  _CatalogSymbolName _parseCatalogSymbolName(final String symbolName) {
    final separator = symbolName.lastIndexOf('.');
    if (separator == -1) {
      return _TopLevelCatalogSymbol(symbolName);
    }
    return _StaticCatalogSymbol(
      symbolName.substring(0, separator),
      symbolName.substring(separator + 1),
    );
  }

  TopLevelVariableElement? _findTopLevelCatalogVariable(
    final LibraryElement library,
    final String name,
  ) {
    for (final element in library.topLevelVariables) {
      if (element.name == name) {
        return element;
      }
    }
    return null;
  }

  FieldElement? _findStaticCatalogField(
    final LibraryElement library,
    final String className,
    final String fieldName,
  ) {
    for (final type in library.classes) {
      if (type.name != className) {
        continue;
      }
      for (final field in type.fields) {
        if (field.isStatic && field.name == fieldName) {
          return field;
        }
      }
    }
    return null;
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
    final seen = <String>{};
    for (final pattern in _toolPartGlobs) {
      await for (final gDart in buildStep.findAssets(Glob(pattern))) {
        if (gDart.path.contains('generated/agent_catalog.g.dart')) {
          continue;
        }
        final parentPath = gDart.path.replaceFirst(
          RegExp(r'\.g\.dart$'),
          '.dart',
        );
        if (_isExcluded(parentPath)) {
          continue;
        }
        if (_isInternalSource(gDart.path) || _isInternalSource(parentPath)) {
          continue;
        }
        final contents = await buildStep.readAsString(gDart);
        if (!contents.contains('_AgentToolPartGenerator')) {
          continue;
        }
        if (!seen.add(parentPath)) {
          continue;
        }
        yield AssetId(gDart.package, parentPath);
      }
    }
  }

  bool _isExcluded(final String path) {
    for (final pattern in _toolExcludeGlobs) {
      if (Glob(pattern).matches(path)) {
        return true;
      }
    }
    return false;
  }

  bool _isInternalSource(final String path) =>
      path.endsWith('lib/builder.dart') ||
      path.endsWith('lib/intentcall_codegen.dart');

  String _projectionLiteral(final ConstantReader reader) {
    final dispatchName = reader.read('dispatchMode').stringValue;
    final surfacesRaw = reader.read('surfaces').mapValue;
    final surfaceEntries = <String>[];
    for (final entry in surfacesRaw.entries) {
      final surfaceName = _surfaceEnumNameFromConstant(entry.key);
      final value = entry.value?.toBoolValue();
      if (surfaceName == null || value == null) {
        continue;
      }
      surfaceEntries.add('AgentManifestSurface.$surfaceName: $value');
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

  String? _surfaceEnumNameFromConstant(final DartObject? key) {
    if (key == null) {
      return null;
    }
    final typeElement = key.type?.element;
    if (typeElement is EnumElement) {
      for (final field in typeElement.fields) {
        if (field.isEnumConstant && field.computeConstantValue() == key) {
          return field.name;
        }
      }
    }
    if (typeElement is FieldElement &&
        typeElement.enclosingElement is EnumElement) {
      return typeElement.name;
    }
    try {
      final stringKey = ConstantReader(key).stringValue;
      return _surfaceEnumNameFromManifestKey(stringKey);
    } on FormatException {
      // Legacy string-key maps only.
    }
    return null;
  }

  String? _surfaceEnumNameFromManifestKey(final String key) {
    const manifestKeyToEnum = <String, String>{
      'web.webMcp': 'webMcp',
      'web.manifestShortcuts': 'webManifestShortcuts',
      'web.protocolHandlers': 'webProtocolHandlers',
      'apple.appShortcuts': 'appleAppShortcuts',
      'android.shortcuts': 'androidShortcuts',
      'windows.protocolActivation': 'windowsProtocolActivation',
      'windows.msixProtocol': 'windowsMsixProtocol',
      'linux.schemeHandler': 'linuxSchemeHandler',
    };
    return manifestKeyToEnum[key];
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

final class _CatalogSpread {
  const _CatalogSpread({
    required this.assetId,
    required this.symbolName,
    required this.importPath,
  });

  final AssetId assetId;
  final String symbolName;
  final String importPath;
}

sealed class _CatalogSymbolName {
  const _CatalogSymbolName();
}

final class _TopLevelCatalogSymbol extends _CatalogSymbolName {
  const _TopLevelCatalogSymbol(this.name);

  final String name;
}

final class _StaticCatalogSymbol extends _CatalogSymbolName {
  const _StaticCatalogSymbol(this.className, this.fieldName);

  final String className;
  final String fieldName;
}
