import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('resourceEnvelope builds intentcall resource uri', () {
    final result = AgentResultEnvelope.resourceEnvelope(
      resourceName: 'spark_runtime_snapshot',
      snapshot: {'phase': 'playing'},
    );
    expect(result.ok, isTrue);
    expect(
      result.data['resource_uri'],
      'intentcall://resource/spark/runtime/snapshot',
    );
  });
}
