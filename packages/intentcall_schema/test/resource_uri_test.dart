import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  test('resourceUri builds app-owned scheme paths', () {
    expect(
      resourceUri(
        protocolScheme: 'demoapp',
        resourceName: 'cool_runtime_snapshot',
      ),
      'demoapp://resource/spark/runtime/snapshot',
    );
  });

  test('resourceUri returns unknown segment for empty name', () {
    expect(
      resourceUri(protocolScheme: 'demoapp', resourceName: ''),
      'demoapp://resource/unknown',
    );
  });
}
