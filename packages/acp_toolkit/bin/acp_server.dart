import 'dart:io';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';

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
Future<void> main(List<String> args) async {
  final backendFlag = args.indexOf('--backend');
  final backendName = backendFlag >= 0 && backendFlag + 1 < args.length
      ? args[backendFlag + 1]
      : 'echo';

  final AcpAgentBackend backend;
  switch (backendName) {
    case 'echo':
      backend = EchoAcpBackend();
    default:
      stderr.writeln('Unknown backend: $backendName (expected echo)');
      exit(2);
  }

  final server = AcpStdioServer(backend: backend);
  await server.run();
}
