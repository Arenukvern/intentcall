import 'dart:io';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:intentcall_core/intentcall_core.dart';

/// ACP stdio server entrypoint.
///
/// Register in Zed (or any ACP client) as an agent command:
///
/// ```sh
/// dart run bin/acp_server.dart --backend echo
/// ```
///
/// Backends:
/// - `echo` — conformance smoke backend, echoes prompts.
/// - `registry` — projects an [AgentRegistry]; tools are invoked by qualified
///   name. Pair with `--entrypoint <dart_file>` to load a registry from a
///   Dart entrypoint exposing `Future<AgentRegistry> Function()` via
///   `build` or a `main` returning the registry (see README).
Future<void> main(List<String> args) async {
  final backendFlag = args.indexOf('--backend');
  final backendName = backendFlag >= 0 && backendFlag + 1 < args.length
      ? args[backendFlag + 1]
      : 'echo';

  final AcpAgentBackend backend;
  switch (backendName) {
    case 'echo':
      backend = EchoAcpBackend();
    case 'registry':
      backend = RegistryAcpBackend(registry: InMemoryAgentRegistry());
    default:
      stderr.writeln('Unknown backend: $backendName (expected echo|registry)');
      exit(2);
  }

  final server = AcpStdioServer(backend: backend);
  await server.run();
}
