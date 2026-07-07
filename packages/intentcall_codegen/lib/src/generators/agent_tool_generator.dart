import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../agent_param.dart';
import '../agent_tool.dart';

/// Generates [RegisteredAgentIntent] / [AgentCallEntry] factories from
/// `@AgentTool` top-level functions and instance methods on host classes.
class AgentToolGenerator extends GeneratorForAnnotation<AgentTool> {
  AgentToolGenerator([this._options]);

  final BuilderOptions? _options;

  static const _agentParamChecker = TypeChecker.typeNamed(AgentParam);
  static const _defaultHostBindingField = 'shared';

  String get _hostBindingField =>
      _options?.config['host_binding_field'] as String? ??
      _defaultHostBindingField;

  @override
  FutureOr<String> generate(
    final LibraryReader library,
    final BuildStep buildStep,
  ) async {
    final values = <String>[];
    final topLevel = await super.generate(library, buildStep);
    if (topLevel.trim().isNotEmpty) {
      values.add(topLevel);
    }

    for (final classElement in library.classes) {
      final instanceMethods = <MethodElement>[];
      for (final method in classElement.methods) {
        final toolAnnotation = typeChecker.firstAnnotationOf(
          method,
          throwOnUnresolved: throwOnUnresolved,
        );
        if (toolAnnotation == null) {
          continue;
        }
        if (method.isStatic) {
          throw InvalidGenerationSourceError(
            '@AgentTool on static methods is not supported; '
            'use top-level @AgentTool or handwritten entry.',
            element: method,
          );
        }
        instanceMethods.add(method);
      }
      if (instanceMethods.isEmpty) {
        continue;
      }

      final bindingField = _hostBindingField;
      if (!_hasBindingField(classElement, bindingField)) {
        throw InvalidGenerationSourceError(
          '@AgentTool instance methods require a static host binding field '
          "'$bindingField' on ${classElement.name}. "
          'Add `static final ${classElement.name} $bindingField = ...` or '
          'configure `host_binding_field` in build.yaml.',
          element: classElement,
        );
      }

      values.add(
        _generateInstanceToolBlock(classElement, instanceMethods, bindingField),
      );
    }

    if (values.isEmpty) {
      return '';
    }
    return values.join('\n\n');
  }

  @override
  String generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    if (element is MethodElement) {
      return '';
    }
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@AgentTool can only annotate top-level functions or instance methods '
        'on host classes.',
        element: element,
      );
    }

    return _generateTopLevelEntry(element, annotation);
  }

  String _generateTopLevelEntry(
    final TopLevelFunctionElement executable,
    final ConstantReader annotation,
  ) {
    _validateExecutable(executable);

    final namespace = annotation.read('namespace').stringValue;
    final name = annotation.read('name').stringValue;
    final description = annotation.read('description').stringValue;

    final schemaName = '_${name}InputSchema';
    final registrationGetter = '${_toCamelCase(name)}Registration';
    final entryGetter = '${_toCamelCase(name)}CallEntry';

    final schemaMap = inputSchemaMapFor(executable);
    final schema = _formatInputSchema(schemaMap);
    final handlerArgs = _buildTopLevelHandlerArgs(executable);

    return '''
const $schemaName = <String, Object?>$schema;

RegisteredAgentIntent get $registrationGetter =>
    $entryGetter.toRegistration();

AgentCallEntry get $entryGetter => AgentCallEntry.tool(
  namespace: ${_literalString(namespace)},
  name: ${_literalString(name)},
  description: ${_literalString(description)},
  inputSchema: $schemaName,
  handler: (final args) async {
$handlerArgs
  },
);
''';
  }

  String _generateInstanceToolBlock(
    final ClassElement classElement,
    final List<MethodElement> methods,
    final String bindingField,
  ) {
    final schemas = <String>[];
    final getters = <String>[];
    final registrations = <String>[];

    for (final method in methods) {
      final toolAnnotation = typeChecker.firstAnnotationOf(
        method,
        throwOnUnresolved: throwOnUnresolved,
      )!;
      final reader = ConstantReader(toolAnnotation);
      _validateExecutable(method);

      final name = reader.read('name').stringValue;
      final schemaName = '_${name}InputSchema';
      final schemaMap = inputSchemaMapFor(method);
      schemas.add(
        'const $schemaName = <String, Object?>${_formatInputSchema(schemaMap)};',
      );
      getters.add(_generateExtensionGetter(method, reader, schemaName));
      registrations.add(
        _generateRegistrationAlias(classElement, method, reader, bindingField),
      );
    }

    return '''
${schemas.join('\n\n')}

extension ${classElement.name}AgentCodegen on ${classElement.name} {
${getters.join('\n\n')}
}

${registrations.join('\n\n')}''';
  }

  String _generateExtensionGetter(
    final MethodElement method,
    final ConstantReader annotation,
    final String schemaName,
  ) {
    final namespace = annotation.read('namespace').stringValue;
    final name = annotation.read('name').stringValue;
    final description = annotation.read('description').stringValue;

    final entryGetter = '${_toCamelCase(name)}CallEntry';
    final handlerArgs = _buildInstanceHandlerArgs(method);

    return '''  AgentCallEntry get $entryGetter => AgentCallEntry.tool(
    namespace: ${_literalString(namespace)},
    name: ${_literalString(name)},
    description: ${_literalString(description)},
    inputSchema: $schemaName,
    handler: (final args) async {
$handlerArgs
    },
  );''';
  }

  String _generateRegistrationAlias(
    final ClassElement classElement,
    final MethodElement method,
    final ConstantReader annotation,
    final String bindingField,
  ) {
    final name = annotation.read('name').stringValue;
    final registrationGetter = '${_toCamelCase(name)}Registration';
    final entryGetter = '${_toCamelCase(name)}CallEntry';
    return '''
RegisteredAgentIntent get $registrationGetter =>
    ${classElement.name}.$bindingField.$entryGetter.toRegistration();''';
  }

  void _validateExecutable(final ExecutableElement executable) {
    if (!_isAgentResultFuture(executable.returnType)) {
      throw InvalidGenerationSourceError(
        '@AgentTool handlers must return Future<AgentResult>.',
        element: executable,
      );
    }
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

  bool _isAgentResultFuture(final DartType type) {
    final display = type.getDisplayString();
    if (display.contains('AgentResult')) {
      return type.isDartAsyncFuture || display.startsWith('Future<');
    }
    if (!type.isDartAsyncFuture) {
      return false;
    }
    final futureType = type as InterfaceType;
    if (futureType.typeArguments.isEmpty) {
      return false;
    }
    final inner = futureType.typeArguments.first;
    final element = inner.element;
    if (element != null && element.name == 'AgentResult') {
      return true;
    }
    final innerDisplay = inner.getDisplayString();
    return innerDisplay == 'AgentResult' ||
        innerDisplay.endsWith('.AgentResult');
  }

  /// Builds JSON-schema-shaped input metadata for manifest and registration.
  Map<String, Object?> inputSchemaMapFor(final ExecutableElement element) {
    final properties = <String, Object?>{};
    final required = <String>[];

    for (final param in element.formalParameters) {
      if (param.isOptionalPositional) {
        throw InvalidGenerationSourceError(
          '@AgentTool does not support optional positional parameters. Use optional named parameters instead.',
          element: param,
        );
      }
      final paramName = param.name;
      if (paramName == null) {
        continue;
      }

      final paramAnnotation = _readAgentParam(param);
      final description =
          paramAnnotation?.read('description').stringValue ?? paramName;
      final isRequired = _isRequiredParameter(param, paramAnnotation);

      final jsonType = _jsonTypeFor(param.type);
      if (jsonType == null) {
        throw InvalidGenerationSourceError(
          'Unsupported @AgentTool parameter type ${param.type.getDisplayString()} for "$paramName". Supported types: String, int, bool, double.',
          element: param,
        );
      }
      properties[paramName] = <String, Object?>{
        'type': jsonType,
        'description': description,
      };

      if (isRequired) {
        required.add(paramName);
      }
    }

    return <String, Object?>{
      'type': 'object',
      'properties': properties,
      'required': required,
    };
  }

  String _formatInputSchema(final Map<String, Object?> schema) {
    final properties = schema['properties']! as Map<String, Object?>;
    final required = (schema['required']! as List<Object?>).cast<String>();
    final propertyLines = properties.entries
        .map(
          (final entry) =>
              "    ${_literalString(entry.key)}: <String, Object?>{'type': ${_literalString((entry.value! as Map)['type'] as String)}, 'description': ${_literalString((entry.value! as Map)['description'] as String)}},",
        )
        .join('\n');
    final requiredLines = required.map(_literalString).join(', ');
    return '''
{
  'type': 'object',
  'properties': <String, Object?>{
$propertyLines
  },
  'required': <String>[$requiredLines],
}''';
  }

  String _buildTopLevelHandlerArgs(final TopLevelFunctionElement element) {
    final positional = <String>[];
    final topLevelNamed = <String>[];
    for (final param in element.formalParameters) {
      final name = param.name;
      if (name == null) {
        continue;
      }
      final cast =
          'args[${_literalString(name)}] as ${_dartTypeName(param.type)}';
      if (param.isNamed) {
        if (_isRequiredParameter(param, _readAgentParam(param))) {
          topLevelNamed.add('#$name: $cast,');
        } else {
          final guard = 'if (args.containsKey(${_literalString(name)}))';
          topLevelNamed.add('$guard #$name: $cast,');
        }
      } else {
        positional.add(cast);
      }
    }

    final namedBlock = topLevelNamed.isEmpty
        ? '<Symbol, Object?>{}'
        : '''
<Symbol, Object?>{
${topLevelNamed.map((final line) => '        $line').join('\n')}
      }''';
    return '''
    final result = Function.apply(
      ${element.name},
      <Object?>[${positional.join(', ')}],
      $namedBlock,
    );
    return await (result as Future<AgentResult>);''';
  }

  String _buildInstanceHandlerArgs(final MethodElement method) {
    final positional = <String>[];
    final instanceNamed = <String>[];
    for (final param in method.formalParameters) {
      final name = param.name;
      if (name == null) {
        continue;
      }
      final cast =
          'args[${_literalString(name)}] as ${_dartTypeName(param.type)}';
      if (param.isNamed) {
        if (_isRequiredParameter(param, _readAgentParam(param))) {
          instanceNamed.add('$name: $cast,');
        } else {
          final guard = 'if (args.containsKey(${_literalString(name)}))';
          instanceNamed.add('$guard $name: $cast,');
        }
      } else {
        positional.add(cast);
      }
    }

    final callArgs = <String>[
      if (positional.isNotEmpty) positional.join(', '),
      if (instanceNamed.isNotEmpty) instanceNamed.join('\n      '),
    ].where((final part) => part.isNotEmpty).join(',\n      ');
    final invocation = callArgs.isEmpty
        ? '${method.name}()'
        : '${method.name}(\n      $callArgs\n    )';
    return '      return await $invocation;';
  }

  ConstantReader? _readAgentParam(final FormalParameterElement param) {
    for (final meta in param.metadata.annotations) {
      final value = ConstantReader(meta.computeConstantValue());
      if (value.instanceOf(_agentParamChecker)) {
        return value;
      }
    }
    return null;
  }

  bool _isRequiredParameter(
    final FormalParameterElement param,
    final ConstantReader? annotation,
  ) => annotation?.read('required').boolValue ?? param.isRequired;

  String? _jsonTypeFor(final DartType type) {
    if (type.isDartCoreInt) {
      return 'integer';
    }
    if (type.isDartCoreBool) {
      return 'boolean';
    }
    if (type.isDartCoreDouble) {
      return 'number';
    }
    if (type.isDartCoreString) {
      return 'string';
    }
    return null;
  }

  String _dartTypeName(final DartType type) {
    final suffix = type.nullabilitySuffix == NullabilitySuffix.question
        ? '?'
        : '';
    if (type.isDartCoreInt) {
      return 'int$suffix';
    }
    if (type.isDartCoreBool) {
      return 'bool$suffix';
    }
    if (type.isDartCoreDouble) {
      return 'double$suffix';
    }
    if (type.isDartCoreString) {
      return 'String$suffix';
    }
    throw StateError('Unsupported Dart type ${type.getDisplayString()}');
  }

  String _literalString(final String value) =>
      "'${value.replaceAll("'", r"\'")}'";

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
