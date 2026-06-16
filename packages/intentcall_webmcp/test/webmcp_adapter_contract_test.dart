import 'package:intentcall_testing/intentcall_testing.dart';
import 'package:intentcall_webmcp/intentcall_webmcp.dart';
import 'package:test/test.dart';

void main() {
  test('WebMcpPublishAdapter satisfies the shared native contract', () async {
    final published =
        <String, Future<Map<String, Object?>> Function(Map<String, Object?>)>{};
    final adapter = WebMcpPublishAdapter(
      publish:
          ({
            required final name,
            required final description,
            required final inputSchema,
            required final execute,
          }) {
            published[name] = execute;
          },
      unpublish: published.remove,
    );

    final proof = await verifyNativeAdapterContract(
      adapter: adapter,
      isPublished: published.containsKey,
      invoke: (final qualifiedName, final arguments) {
        final invoker = published[qualifiedName];
        if (invoker == null) {
          throw StateError('No WebMCP tool published for $qualifiedName');
        }
        return invoker(arguments);
      },
      normalize: normalizeAdapterMapResult,
    );

    expect(proof.adapterId, 'webmcp');
    expect(proof.hotSyncProven, isTrue);
    expect(proof.detachCleanupProven, isTrue);
  });
}
