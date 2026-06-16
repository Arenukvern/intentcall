import 'package:intentcall_gemma/intentcall_gemma.dart';
import 'package:intentcall_testing/intentcall_testing.dart';
import 'package:test/test.dart';

void main() {
  test('GemmaPublishAdapter satisfies the shared native contract', () async {
    final published = <String, GemmaToolInvoker>{};
    final adapter = GemmaPublishAdapter(
      register: (final definition, final invoker) {
        published[definition.name] = invoker;
      },
      unregister: published.remove,
    );

    final proof = await verifyNativeAdapterContract(
      adapter: adapter,
      isPublished: published.containsKey,
      invoke: (final qualifiedName, final arguments) {
        final invoker = published[qualifiedName];
        if (invoker == null) {
          throw StateError('No Gemma tool published for $qualifiedName');
        }
        return invoker(arguments);
      },
      normalize: normalizeAdapterMapResult,
    );

    expect(proof.adapterId, 'gemma');
    expect(proof.hotSyncProven, isFalse);
    expect(proof.detachCleanupProven, isTrue);
  });
}
