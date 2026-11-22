import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  group('tryDecodeDartMap', () {
    test('recovers the real service-extension shapes', () {
      expect(tryDecodeDartMap('{width: 2.0, color: 4294918846}'), {
        'width': 2.0,
        'color': 4294918846,
      });
      // The live-drive payload that could not round-trip before:
      // bare keys, `#` values (a bare string token).
      expect(tryDecodeDartMap('{winter: #FF6A00, summer: 4286837026}'), {
        'winter': '#FF6A00',
        'summer': 4286837026,
      });
    });

    test('recovers nested maps, lists, keywords', () {
      expect(tryDecodeDartMap('{a: {b: [1, 2]}, c: true, d: null}'), {
        'a': <String, Object?>{'b': <Object?>[1, 2]},
        'c': true,
        'd': null,
      });
    });

    test('recovers empty map', () {
      expect(tryDecodeDartMap('{}'), <String, Object?>{});
      expect(tryDecodeDartMap('{ }'), <String, Object?>{});
    });

    test('recovers quoted values and keys', () {
      expect(tryDecodeDartMap("{greeting: 'hello world'}"), {
        'greeting': 'hello world',
      });
      expect(tryDecodeDartMap('{"key": "value"}'), {'key': 'value'});
    });

    test('tolerates whitespace', () {
      expect(tryDecodeDartMap('{ a : 1 , b : 2.5 }'), {'a': 1, 'b': 2.5});
    });

    test('null on malformed input', () {
      expect(tryDecodeDartMap('{a: 1'), isNull); // unbalanced
      expect(tryDecodeDartMap('a: 1}'), isNull); // no opening brace
      expect(tryDecodeDartMap('{a 1}'), isNull); // missing colon
      expect(tryDecodeDartMap('{a: 1} extra'), isNull); // trailing junk
      expect(tryDecodeDartMap('not an object'), isNull);
      expect(tryDecodeDartMap(''), isNull);
    });

    test('integer keys refuse as keys but numbers survive as values', () {
      // Dart map toString prints int keys bare: {1: a} — not a
      // string-keyed JSON map, so recovery refuses rather than lying.
      expect(tryDecodeDartMap('{1: a}'), isNull);
    });
  });

  group('tryDecodeDartList', () {
    test('recovers flat and nested lists', () {
      expect(tryDecodeDartList('[[1, 2], [3, 4]]'), <Object?>[
        <Object?>[1, 2],
        <Object?>[3, 4],
      ]);
      // A Dart list of maps — the shape that threw FormatException out of
      // the old unguarded jsonDecode.
      expect(tryDecodeDartList('[{winter: #FF6A00}]'), <Object?>[
        <String, Object?>{'winter': '#FF6A00'},
      ]);
      expect(tryDecodeDartList('[true, false, null, -2.5]'), <Object?>[
        true,
        false,
        null,
        -2.5,
      ]);
    });

    test('recovers empty list', () {
      expect(tryDecodeDartList('[]'), <Object?>[]);
    });

    test('null on malformed input', () {
      expect(tryDecodeDartList('[1, 2'), isNull);
      expect(tryDecodeDartList('nope'), isNull);
    });
  });

  group('tryDecodeDartLiteral', () {
    test('recovers bare scalars', () {
      expect(tryDecodeDartLiteral('true'), isTrue);
      expect(tryDecodeDartLiteral('false'), isFalse);
      expect(tryDecodeDartLiteral('null'), isNull);
      expect(tryDecodeDartLiteral('42'), 42);
      expect(tryDecodeDartLiteral('-1.5'), -1.5);
      expect(tryDecodeDartLiteral('plain token'), 'plain token');
    });

    test('JSON text decodes through the same parser', () {
      // toString never emits JSON, but accepting it costs nothing and
      // makes the recovery path a superset.
      expect(tryDecodeDartLiteral('{"a": [1, {"b": true}]}'), {
        'a': <Object?>[1, <String, Object?>{'b': true}],
      });
    });
  });
}
