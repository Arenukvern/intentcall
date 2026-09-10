// ignore_for_file: lines_longer_as_80_chars

/// The tier contract's wire seam (server-side tier enforcement, follow-up
/// 1): `AcpSessionNewRequest` carries the ACP `_meta` object through
/// fromJson/toJson so a client can declare `_meta.sessionTier` at
/// session/new and the agent backend receives it. Additive — absent
/// `_meta` decodes exactly as before (tolerated-and-dropped convention).
library;

import 'package:dart_acp_toolkit/dart_acp_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test('fromJson carries _meta.sessionTier through; toJson round-trips it',
      () {
    const wire = {
      'cwd': '/tmp/proj',
      '_meta': {
        'sessionTier': {
          'backend': 'apple_foundation_afm',
          'windowTokens': 4096,
          'outputReserveTokens': 1024,
          'perOpReadBudget': 512,
          'verdictBudget': 1200,
        },
      },
    };
    final request = AcpSessionNewRequest.fromJson(wire);
    expect(request.cwd, '/tmp/proj');
    expect(request.meta, isNotNull);
    final tier = request.meta!['sessionTier'] as Map<String, Object?>;
    expect(tier['windowTokens'], 4096);
    expect(tier['perOpReadBudget'], 512);

    // Round-trip: other _meta entries and the tier ride unchanged.
    final out = request.toJson();
    expect((out['_meta'] as Map)['sessionTier'], tier);
    expect(out['cwd'], '/tmp/proj');

    // And the decoded round-trip is stable (a second fromJson sees the
    // same tier — the extension's client → daemon path).
    final again = AcpSessionNewRequest.fromJson(out);
    expect(
      (again.meta!['sessionTier'] as Map)['verdictBudget'],
      1200,
    );
  });

  test('absent or non-object _meta → null (tolerated and dropped, the '
      'unknown-param convention); toJson omits the key', () {
    final absent = AcpSessionNewRequest.fromJson({'cwd': '/tmp'});
    expect(absent.meta, isNull);
    expect(absent.toJson().containsKey('_meta'), isFalse);

    // A non-object _meta must not throw — dropped like any unknown param.
    final dropped = AcpSessionNewRequest.fromJson({'cwd': '/tmp', '_meta': 7});
    expect(dropped.meta, isNull);

    // mcpServers still decode as before (additive, never a behavior
    // change for the existing wire shape).
    final servers = AcpSessionNewRequest.fromJson({
      'cwd': '/tmp',
      'mcpServers': [
        {'name': 'a'},
      ],
    });
    expect(servers.mcpServers, hasLength(1));
  });
}
