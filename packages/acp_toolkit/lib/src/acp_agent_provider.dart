/// The IntentCall adapter (oka ADR-0026 R3.3): an ACP agent subprocess as a
/// composition component.
///
/// Readiness **is** the ACP `initialize` versioned handshake — the protocol
/// stays in the provider (ADR-0026 decision 10: session protocols live in
/// adapters); what the contract sees is a declared, budgeted readiness, a
/// typed output (the negotiated protocol version), and lifecycle operations
/// with verified stops: `dispose()` awaits the agent's death, so a
/// composition teardown can never leave the subprocess behind.
///
/// Sessions are memory-only in this toolkit, so the provider declares no
/// `durableIdentity`: a dead process cannot be adopted, only reported.
library;

import 'dart:async';
import 'dart:io';

import 'package:resource_composition/resource_composition.dart';

import 'acp_client.dart';

/// Typed output: the protocol version the agent negotiated down to.
final acpNegotiatedProtocolVersion =
    OutputRef<int>('acp-agent.protocol_version');

/// Spawns an ACP agent subprocess that is ready when the handshake answers.
final class AcpAgentProvider implements ResourceProvider {
  /// Spawns [command] — argv: executable followed by arguments.
  AcpAgentProvider({
    required List<String> command,
    this.workingDirectory,
    this.protocolVersion = 1,
  }) : command = List.of(command);

  final List<String> command;
  final String? workingDirectory;
  final int protocolVersion;

  /// Live clients by [ResourceRef.handle]; a provider instance is
  /// per-component (constructor injection), so this never crosses
  /// compositions.
  final _clients = <String, AcpClient>{};

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        readinessProbe: true,
      );

  @override
  Future<StartReport> start(final StartRequest request) async {
    if (request.mode == StartMode.attach) {
      throw StateError(
        'AcpAgentProvider owns what it spawns; attach is not a capability '
        '(ACP sessions are memory-only — there is nothing to attach to).',
      );
    }
    final client = await AcpClient.spawn(
      command.first,
      command.sublist(1),
      workingDirectory: workingDirectory,
      protocolVersion: protocolVersion,
    );
    final pid = client.processPid;
    try {
      // The handshake IS the readiness probe (provider-owned mechanics);
      // cancellation is honored by racing it — the runner never abandons.
      final winner = await Future.any<Object?>([
        client.initialize().then((_) => 'ready'),
        request.cancellation.future,
      ]);
      if (winner == null && request.cancellation.isCancelled) {
        await client.dispose();
        throw StartCancelled(request.component.id);
      }
    } on Object {
      // A failed start leaves nothing running.
      await client.dispose();
      rethrow;
    }
    final handle = 'acp-agent:${request.component.id}:$pid';
    _clients[handle] = client;
    return StartReport(
      ref: ResourceRef(
        componentId: request.component.id,
        handle: handle,
        pid: pid,
      ),
      outputs: ResolvedOutputs({
        acpNegotiatedProtocolVersion.id: protocolVersion,
      }),
    );
  }

  @override
  Future<Observation> inspect(final ResourceRef ref) async {
    final client = _clients[ref.handle];
    if (client == null || client.isClosed) {
      return const Observation(
        state: ResourceState.stopped,
        cause: TerminalCause.unknown,
      );
    }
    final alive = await _pidAlive(ref.pid);
    if (alive == null) {
      return const Observation(
        state: ResourceState.unknown,
        cause: TerminalCause.unknown,
        message: 'pid could not be probed; report-never-guess',
      );
    }
    return alive
        ? const Observation(state: ResourceState.ready)
        : const Observation(
            state: ResourceState.stopped,
            cause: TerminalCause.unknown,
          );
  }

  @override
  Future<StopReport> stop(
    final ResourceRef ref, {
    required final Duration grace,
  }) async {
    final client = _clients.remove(ref.handle);
    if (client == null) {
      return const StopReport(
        disposition: StopDisposition.alreadyStopped,
        cause: TerminalCause.exited,
      );
    }
    // dispose() is the verified-stop ladder (SIGTERM → grace → SIGKILL,
    // death awaited, self-bounded); we never cut it short mid-ladder —
    // that would abandon the child half-dead.
    await client.dispose();
    return const StopReport(
      disposition: StopDisposition.stopped,
      cause: TerminalCause.exited,
    );
  }

  @override
  Future<Observation> reconcile(final ResourceRef ref) async {
    final client = _clients[ref.handle];
    if (client == null) {
      return const Observation(
        state: ResourceState.unknown,
        cause: TerminalCause.unknown,
        message: 'no live client handle; sessions are memory-only and cannot '
            'be adopted after a crash — report, never guess',
      );
    }
    return inspect(ref);
  }

  /// POSIX `kill -0` probe; null when liveness cannot be established
  /// (Windows probe pending — report-never-guess either way).
  Future<bool?> _pidAlive(final int? pid) async {
    if (pid == null || pid <= 0) return null;
    if (Platform.isWindows) return null;
    try {
      final result = await Process.run('kill', <String>['-0', '$pid']);
      return result.exitCode == 0;
    } on Object {
      return null;
    }
  }
}
