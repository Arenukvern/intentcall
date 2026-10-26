/// Owner-bound ACP filesystem and terminal services. This transport creates no
/// files or processes; callbacks retain the owner's native authority.
typedef AcpClientServiceHandler =
    Future<Map<String, Object?>> Function(Map<String, Object?> parameters);

final class AcpClientServices {
  AcpClientServices({
    required this.canAccessSession,
    this.readTextFile,
    this.writeTextFile,
    Map<String, AcpClientServiceHandler> terminalMethods = const {},
  }) : terminalMethods = Map.unmodifiable(terminalMethods) {
    if (terminalMethods.isNotEmpty &&
        (terminalMethods.length != terminalMethodNames.length ||
            !terminalMethodNames.every(terminalMethods.containsKey))) {
      throw ArgumentError('Bind the complete ACP terminal lifecycle');
    }
  }

  final bool Function(String sessionId) canAccessSession;
  final AcpClientServiceHandler? readTextFile;
  final AcpClientServiceHandler? writeTextFile;
  final Map<String, AcpClientServiceHandler> terminalMethods;
  static const terminalMethodNames = {
    'terminal/create',
    'terminal/output',
    'terminal/release',
    'terminal/wait_for_exit',
    'terminal/kill',
  };

  Map<String, Object?> get capabilities => {
    'fs': {
      'readTextFile': readTextFile != null,
      'writeTextFile': writeTextFile != null,
    },
    'terminal': terminalMethods.isNotEmpty,
  };

  static bool isServiceMethod(String method) =>
      method.startsWith('fs/') || method.startsWith('terminal/');

  Future<Map<String, Object?>> handle(
    String method,
    Map<String, Object?> parameters,
  ) async {
    final handler = switch (method) {
      'fs/read_text_file' => readTextFile,
      'fs/write_text_file' => writeTextFile,
      _ => terminalMethods[method],
    };
    if (handler == null) throw UnimplementedError();
    final session = parameters['sessionId'];
    if (session is! String || session.isEmpty || !canAccessSession(session)) {
      throw StateError('acp_service_scope_not_bound');
    }
    return handler(parameters);
  }
}
