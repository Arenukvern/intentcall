import 'dart:async';

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test(
    'external stream disposal awaits owner and repeated calls share it',
    () async {
      final output = StreamController<List<int>>();
      final settlement = Completer<void>();
      var calls = 0;
      final client = AcpClient(
        agentOutput: output.stream,
        agentInput: StringBuffer(),
        onTransportDispose: () {
          calls++;
          return settlement.future;
        },
      );
      var completed = false;
      final first = client.dispose();
      unawaited(first.then((_) => completed = true));
      final second = client.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(calls, 1);
      expect(identical(first, second), isTrue);
      settlement.complete();
      await first;
      expect(completed, isTrue);
      await output.close();
    },
  );

  test(
    'unknown owner settlement remains a failed disposal on retries',
    () async {
      final output = StreamController<List<int>>();
      var calls = 0;
      final client = AcpClient(
        agentOutput: output.stream,
        agentInput: StringBuffer(),
        onTransportDispose: () async {
          calls++;
          throw StateError('owned_transport_settlement_unknown');
        },
      );
      await expectLater(client.dispose(), throwsStateError);
      await expectLater(client.dispose(), throwsStateError);
      expect(calls, 1);
      await output.close();
    },
  );
}
