import 'dart:async';
import 'dart:convert';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

/// An agent that refuses `session/new` with auth_required until
/// `session/authenticate` names its advertised method.
class _AuthGatedBackend implements AcpAgentBackend, AcpAuthenticating {
  final _authenticated = <String>{};

  @override
  String get name => 'auth-gated';
  @override
  String get version => '0.0.1';

  @override
  Map<String, Object?> get agentCapabilities => const {};

  /// Advertised at initialize (the client captures these).
  Map<String, Object?> authMethod() => {
    'id': 'oauth-personal',
    'name': 'Log in with Google',
    'description': 'Browser OAuth flow',
  };

  @override
  Future<String> createSession(AcpSessionNewRequest request) async {
    if (_authenticated.isEmpty) {
      throw AcpAgentError(
        code: -32000,
        message: 'Authentication required',
        data: {'authMethods': [authMethod()]},
      );
    }
    return 's-${_authenticated.first}';
  }

  @override
  Future<AcpStopReason> prompt(
    AcpPromptRequest request, {
    required void Function(AcpSessionUpdate update) emit,
    required bool Function() isCancelled,
  }) async {
    emit(const AgentMessageChunk(content: AcpTextBlock('signed in')));
    return AcpStopReason.endTurn;
  }

  @override
  List<Map<String, Object?>> get authMethods => [authMethod()];

  @override
  Future<AcpPermissionOutcome> requestPermission(
    AcpPermissionRequest request,
  ) async => AcpPermissionOutcome.allow;

  @override
  Future<bool> authenticate(String methodId) async {
    if (methodId != 'oauth-personal') return false;
    _authenticated.add(methodId);
    return true;
  }

  @override
  void cancelSession(String sessionId) {}

  @override
  Future<void> disposeSession(String sessionId) async {}
}

final class _ForwardSink implements StringSink {
  _ForwardSink(this._target);
  final StreamController<List<int>> _target;

  @override
  void writeln([Object? object = '']) {
    final text = '$object';
    if (text.trim().isEmpty) return;
    _target.add(utf8.encode('$text\n'));
  }

  @override
  void write(Object? object) => writeln(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
}

void main() {
  test(
    'auth_required flows: typed refusal with methods, authenticate, retry',
    () async {
      final fromClient = StreamController<List<int>>();
      final fromServer = StreamController<List<int>>();
      final backend = _AuthGatedBackend();
      final server = AcpStdioServer(
        backend: backend,
        inputStream: fromClient.stream,
        outputSink: _ForwardSink(fromServer),
      );
      server.run().ignore();

      final client = AcpClient(
        agentOutput: fromServer.stream,
        agentInput: _ForwardSink(fromClient),
      );
      await client.initialize();
      // The agent advertises its method at initialize.
      expect(client.authMethods.single.methodId, 'oauth-personal');

      // Unauthenticated session/new refuses, typed, carrying the method.
      await expectLater(
        client.newSession(cwd: '/tmp/x'),
        throwsA(
          isA<AcpAuthRequiredException>().having(
            (error) => error.authMethods.single.methodId,
            'authMethods',
            'oauth-personal',
          ),
        ),
      );

      // The client answers session/authenticate; the next session/new
      // succeeds.
      await client.authenticate('oauth-personal');
      final sessionId = await client.newSession(cwd: '/tmp/x');
      expect(sessionId, 's-oauth-personal');

      final result = await client.promptText(sessionId, 'hi');
      expect(result.stopReason, AcpStopReason.endTurn);

      await client.dispose();
      await fromClient.close();
      await fromServer.close();
    },
  );
}
