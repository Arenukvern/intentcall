// The IntentCall adapter (oka ADR-0026 R3.3): an ACP agent subprocess as a
// composition component — readiness is the `initialize` handshake, stop is
// a verified death.
import 'dart:io';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:resource_composition/resource_composition.dart';
import 'package:test/test.dart';

void main() {
  test('spawns the echo agent, becomes ready via the handshake, and stops '
      'with verified death', () async {
    final provider = AcpAgentProvider(
      command: <String>[
        Platform.resolvedExecutable,
        'run',
        'bin/acp_server.dart',
        '--backend',
        'echo',
      ],
    );
    final request = StartRequest(
      component: Component(id: 'agent', provider: provider),
      mode: StartMode.start,
      dependencies: ResolvedOutputs.empty,
      readinessBudget: const Duration(seconds: 60),
      cancellation: Cancellation(),
    );
    final report = await provider.start(request);
    expect(report.attached, isFalse);
    expect(
      report.outputs.require(acpNegotiatedProtocolVersion),
      1,
    );

    final ready = await provider.inspect(report.ref);
    expect(ready.state, ResourceState.ready);

    final stop = await provider.stop(
      report.ref,
      grace: const Duration(seconds: 10),
    );
    expect(stop.disposition, StopDisposition.stopped);

    final after = await provider.inspect(report.ref);
    expect(after.state, ResourceState.stopped);
    final pid = report.ref.pid!;
    // Verified death, not fire-and-forget: a later `kill -0` must fail.
    if (!Platform.isWindows) {
      final probe = await Process.run('kill', <String>['-0', '$pid']);
      expect(probe.exitCode, isNot(0), reason: 'agent pid $pid still alive');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('attach is refused: ACP sessions are memory-only', () async {
    final provider = AcpAgentProvider(command: <String>['never-spawned']);
    await expectLater(
      provider.start(
        StartRequest(
          component: Component(id: 'agent', provider: provider),
          mode: StartMode.attach,
          dependencies: ResolvedOutputs.empty,
          readinessBudget: const Duration(seconds: 1),
          cancellation: Cancellation(),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
