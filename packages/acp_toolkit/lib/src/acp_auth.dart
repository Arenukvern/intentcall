/// An error a backend raises deliberately (e.g. auth_required from
/// `createSession`); the server forwards it as a JSON-RPC error response
/// with the same [code]/[message]/[data] instead of a generic -32603.
class AcpAgentError implements Exception {
  AcpAgentError({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => 'AcpAgentError($code): $message';
}

/// Opt-in backend authentication surface (the `AcpPermissionRequesting`
/// pattern): advertise methods at `initialize` and answer
/// `session/authenticate`. Backends that manage credentials entirely in
/// their own store simply don't implement it.
abstract interface class AcpAuthenticating {
  /// Methods advertised in the initialize response (`authMethods`).
  List<Map<String, Object?>> get authMethods;

  /// Answers `session/authenticate`; true when the agent is now
  /// authenticated (e.g. an OAuth URL was approved out of band).
  Future<bool> authenticate(String methodId);
}

/// One authentication method an agent advertises at `initialize`
/// (`authMethods`), e.g. `oauth-personal` / "Log in with Google".
class AcpAuthMethod {
  const AcpAuthMethod({required this.methodId, this.name, this.description});

  factory AcpAuthMethod.fromJson(Map<String, Object?> json) => AcpAuthMethod(
    methodId: json['id'] as String? ?? json['methodId'] as String? ?? '',
    name: json['name'] as String?,
    description: json['description'] as String?,
  );

  final String methodId;
  final String? name;
  final String? description;

  @override
  String toString() => name ?? methodId;
}

/// A JSON-RPC error response from the agent (non-negative id, `error`
/// present). Typed so clients can branch on [code] without parsing
/// strings.
class AcpRemoteError implements Exception {
  AcpRemoteError(this.code, this.message, [this.data]);

  factory AcpRemoteError.fromMap(Map<String, Object?> error) =>
      AcpRemoteError(
        (error['code'] as num?)?.toInt() ?? 0,
        '${error['message'] ?? 'unknown agent error'}',
        error['data'],
      );

  final int code;
  final String message;

  /// Free-form error payload (e.g. `authMethods` on auth_required).
  final Object? data;

  @override
  String toString() => 'AcpRemoteError($code): $message';
}

/// `session/new` refused because the agent requires authentication
/// (JSON-RPC `-32000` / `auth_required`). The advertised [authMethods]
/// ride along; the client answers with `session/authenticate` — or, for
/// terminal-auth agents, directs the user to the agent's own login flow.
class AcpAuthRequiredException implements Exception {
  AcpAuthRequiredException({required this.message, this.authMethods = const []});

  final String message;

  /// Methods taken from the error `data` when present, else the methods
  /// advertised at `initialize`.
  final List<AcpAuthMethod> authMethods;

  @override
  String toString() => 'AcpAuthRequiredException: $message';
}
