import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generators/agent_catalog_generator.dart';
import 'src/generators/agent_tool_generator.dart';

/// build_runner builder for `@AgentTool` → `.g.dart` registration factories.
Builder agentToolBuilder(final BuilderOptions options) => PartBuilder(
  [AgentToolGenerator()],
  '.g.dart',
  header: '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
''',
);

/// Aggregates all `@AgentTool` registrations into `lib/generated/agent_catalog.g.dart`.
Builder agentCatalogBuilder(final BuilderOptions options) =>
    AgentCatalogGenerator(options);
