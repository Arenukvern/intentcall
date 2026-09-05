import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generators/agent_catalog_generator.dart';
import 'src/generators/agent_tool_generator.dart';

/// Wraps [AgentToolGenerator] as a plain [Generator] so [PartBuilder] runs for
/// instance-method `@AgentTool` annotations (not only top-level declarations).
final class _AgentToolPartGenerator extends Generator {
  _AgentToolPartGenerator(this._delegate);

  final AgentToolGenerator _delegate;

  @override
  FutureOr<String?> generate(
    final LibraryReader library,
    final BuildStep buildStep,
  ) => _delegate.generate(library, buildStep);
}

/// build_runner builder for `@AgentTool` → `.g.dart` registration factories.
Builder agentToolBuilder(final BuilderOptions options) => PartBuilder(
  [_AgentToolPartGenerator(AgentToolGenerator(options))],
  '.g.dart',
  header: '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
''',
);

/// Aggregates `@AgentTool` and `@AgentCatalog` rows into `lib/generated/agent_catalog.g.dart`.
///
/// See [AgentCatalogGenerator] and [AgentCatalog].
Builder agentCatalogBuilder(final BuilderOptions options) =>
    AgentCatalogGenerator(options);
