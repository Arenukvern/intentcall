import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('resourceEnvelope builds app-owned resource uri', () {
    final result = AgentResultEnvelope.resourceEnvelope(
      protocolScheme: 'demoapp',
      resourceName: 'cool_runtime_snapshot',
      snapshot: {'phase': 'playing'},
    );
    expect(result.ok, isTrue);
    expect(
      result.data['resource_uri'],
      'demoapp://resource/spark/runtime/snapshot',
    );
  });
}
