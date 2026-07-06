import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../agent_param.dart';
import '../agent_tool.dart';

/// Generates [RegisteredAgentIntent] / [AgentCallEntry] factories from
/// `@AgentTool` functions (Phase 5-C pilot).
class AgentToolGenerator extends GeneratorForAnnotation<AgentTool> {
  static const _agentParamChecker = TypeChecker.typeNamed(AgentParam);

  @override
  String generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@AgentTool can only annotate top-level functions.',
        element: element,
      );
    }

    final returnType = element.returnType;
    if (!_isAgentResultFuture(returnType)) {
      throw InvalidGenerationSourceError(
        '@AgentTool functions must return Future<AgentResult>.',
        element: element,
      );
    }

    final namespace = annotation.read('namespace').stringValue;
    final name = annotation.read('name').stringValue;
    final description = annotation.read('description').stringValue;

    final schemaName = '_${name}InputSchema';
    final registrationGetter = '${_toCamelCase(name)}Registration';
    final entryGetter = '${_toCamelCase(name)}CallEntry';

    final schemaMap = inputSchemaMapFor(element);
    final schema = _formatInputSchema(schemaMap);
    final handlerArgs = _buildHandlerArgs(element);

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

  bool _isAgentResultFuture(final DartType type) {
    if (!type.isDartAsyncFuture) {
      return false;
    }
    final futureType = type as InterfaceType;
    if (futureType.typeArguments.isEmpty) {
      return false;
    }
    final inner = futureType.typeArguments.first;
    return inner.getDisplayString() == 'AgentResult';
  }

  /// Builds JSON-schema-shaped input metadata for manifest and registration.
  Map<String, Object?> inputSchemaMapFor(
    final TopLevelFunctionElement element,
  ) {
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

  String _buildHandlerArgs(final TopLevelFunctionElement element) {
    final positional = <String>[];
    final named = <String>[];
    for (final param in element.formalParameters) {
      final name = param.name;
      if (name == null) {
        continue;
      }
      final cast =
          'args[${_literalString(name)}] as ${_dartTypeName(param.type)}';
      if (param.isNamed) {
        if (_isRequiredParameter(param, _readAgentParam(param))) {
          named.add('#$name: $cast,');
        } else {
          named.add(
            'if (args.containsKey(${_literalString(name)})) #$name: $cast,',
          );
        }
      } else {
        positional.add(cast);
      }
    }
    return '''
    final result = Function.apply(
      ${element.name},
      <Object?>[${positional.join(', ')}],
      <Symbol, Object?>{
${named.map((final line) => '        $line').join('\n')}
      },
    );
    return await (result as Future<AgentResult>);''';
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
