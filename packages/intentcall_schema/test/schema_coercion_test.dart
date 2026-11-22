import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  const tapSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['ref'],
    'properties': {
      'ref': {'type': 'string'},
      'snapshotId': {'type': 'integer'},
    },
  };

  test('coerces integer and bool wire strings', () {
    final coerced = coerceArgumentsForSchema(tapSchema, {
      'ref': 's_0',
      'snapshotId': '42',
    });
    expect(coerced['ref'], 's_0');
    expect(coerced['snapshotId'], 42);
    expect(() => validateAgainstSchema(tapSchema, coerced), returnsNormally);
  });

  test('coerces boolean wire strings', () {
    const schema = {
      'type': 'object',
      'properties': {
        'strict': {'type': 'boolean'},
      },
    };
    for (final entry in [
      ('true', true),
      ('false', false),
      ('1', true),
      ('0', false),
      ('yes', true),
      ('no', false),
    ]) {
      final coerced = coerceArgumentsForSchema(schema, {'strict': entry.$1});
      expect(coerced['strict'], entry.$2, reason: 'wire ${entry.$1}');
      expect(() => validateAgainstSchema(schema, coerced), returnsNormally);
    }
  });

  test('omits empty non-string wire values', () {
    final coerced = coerceArgumentsForSchema(tapSchema, {
      'ref': 's_0',
      'snapshotId': '   ',
    });
    expect(coerced.containsKey('snapshotId'), isFalse);
    expect(() => validateAgainstSchema(tapSchema, coerced), returnsNormally);
  });

  test('coerces json object wire strings', () {
    const waitSchema = {
      'type': 'object',
      'required': ['predicate'],
      'properties': {
        'predicate': {'type': 'object'},
        'timeoutMs': {'type': 'integer'},
      },
    };
    final coerced = coerceArgumentsForSchema(waitSchema, {
      'predicate': '{"kind":"time","ms":50}',
      'timeoutMs': '5000',
    });
    expect(coerced['predicate'], {'kind': 'time', 'ms': 50});
    expect(coerced['timeoutMs'], 5000);
    expect(() => validateAgainstSchema(waitSchema, coerced), returnsNormally);
  });

  test('leaves already-typed values unchanged', () {
    final coerced = coerceArgumentsForSchema(tapSchema, {
      'ref': 's_0',
      'snapshotId': 7,
    });
    expect(coerced['snapshotId'], 7);
  });

  test('does not coerce product-specific open object fields', () {
    const waitSchema = {
      'type': 'object',
      'required': ['predicate'],
      'properties': {
        'predicate': {'type': 'object', 'additionalProperties': true},
        'timeoutMs': {'type': 'integer'},
      },
    };
    final coerced = coerceArgumentsForSchema(waitSchema, {
      'predicate': {'kind': 'time', 'ms': '50'},
      'timeoutMs': '1000',
    });
    expect(coerced['predicate'], {'kind': 'time', 'ms': '50'});
    expect(coerced['timeoutMs'], 1000);
    expect(() => validateAgainstSchema(waitSchema, coerced), returnsNormally);
  });

  test('coerces nested values only when schema declares nested properties', () {
    const waitSchema = {
      'type': 'object',
      'required': ['predicate'],
      'properties': {
        'predicate': {
          'type': 'object',
          'required': ['kind', 'stableWindowMs'],
          'properties': {
            'kind': {'type': 'string'},
            'stableWindowMs': {'type': 'integer'},
          },
        },
      },
    };
    final stable = coerceArgumentsForSchema(waitSchema, {
      'predicate': {'kind': 'stable', 'stableWindowMs': '300'},
    });
    expect(stable['predicate'], {'kind': 'stable', 'stableWindowMs': 300});
    expect(() => validateAgainstSchema(waitSchema, stable), returnsNormally);
  });

  // The service-extension flattening: Flutter's binding hands every
  // parameter to the callback as a string, so complex arguments arrive as
  // Dart `toString()` text — not JSON. Coercion must recover the common
  // shapes and never throw on the rest (pass through → honest validation
  // refusal instead).
  group('dart-literal wire recovery', () {
    const patchSchema = {
      'type': 'object',
      'required': ['patch'],
      'properties': {
        'patch': {'type': 'object', 'additionalProperties': true},
      },
    };
    const tilesSchema = {
      'type': 'object',
      'required': ['tiles'],
      'properties': {
        'tiles': {
          'type': 'array',
          'items': {'type': 'array'},
        },
      },
    };

    test('recovers a Dart toString map for an object-typed arg', () {
      final coerced = coerceArgumentsForSchema(patchSchema, {
        'patch': '{width: 2.0, color: 4294918846}',
      });
      expect(coerced['patch'], {'width': 2.0, 'color': 4294918846});
      expect(
        () => validateAgainstSchema(patchSchema, coerced),
        returnsNormally,
      );
    });

    test('recovers bare string values with special characters', () {
      // The payload that could not round-trip before the fix.
      final coerced = coerceArgumentsForSchema(patchSchema, {
        'patch': '{canopyColors: {winter: #FF6A00}}',
      });
      expect(coerced['patch'], {
        'canopyColors': {'winter': '#FF6A00'},
      });
    });

    test('recovers an empty object', () {
      final coerced = coerceArgumentsForSchema(patchSchema, {'patch': '{}'});
      expect(coerced['patch'], <String, Object?>{});
    });

    test('recovers a Dart toString list for an array-typed arg', () {
      final coerced = coerceArgumentsForSchema(tilesSchema, {
        'tiles': '[[1, 2], [3, 4]]',
      });
      expect(coerced['tiles'], <Object?>[
        <Object?>[1, 2],
        <Object?>[3, 4],
      ]);
      expect(
        () => validateAgainstSchema(tilesSchema, coerced),
        returnsNormally,
      );
    });

    test('passes non-decodable text through instead of throwing', () {
      final coercedObject = coerceArgumentsForSchema(patchSchema, {
        'patch': 'not an object',
      });
      expect(coercedObject['patch'], 'not an object');
      expect(
        () => validateAgainstSchema(patchSchema, coercedObject),
        throwsA(isA<AgentValidationException>()),
      );

      final coercedList = coerceArgumentsForSchema(tilesSchema, {
        'tiles': '[1, 2', // truncated
      });
      expect(coercedList['tiles'], '[1, 2');
    });

    test('JSON text still decodes exactly as before', () {
      final coerced = coerceArgumentsForSchema(patchSchema, {
        'patch': '{"winter": "#FF6A00"}',
      });
      expect(coerced['patch'], {'winter': '#FF6A00'});
    });

    test('open-object string entries recover Dart maps', () {
      const schema = {
        'type': 'object',
        'properties': {
          'options': {'type': 'object', 'additionalProperties': true},
        },
      };
      final coerced = coerceArgumentsForSchema(schema, {
        'options': {'colors': '{winter: #FF6A00}'},
      });
      expect(coerced['options'], {
        'colors': {'winter': '#FF6A00'},
      });
    });
  });

  group('wire encode round-trip', () {
    const schema = {
      'type': 'object',
      'required': ['id', 'patch', 'tiles', 'strict'],
      'properties': {
        'id': {'type': 'string'},
        'patch': {'type': 'object', 'additionalProperties': true},
        'tiles': {
          'type': 'array',
          'items': {'type': 'integer'},
        },
        'strict': {'type': 'boolean'},
      },
    };

    test('encode -> flattened wire -> coerce reproduces the arguments', () {
      final arguments = <String, Object?>{
        'id': 'material/grass',
        'patch': <String, Object?>{
          'canopyColors': <String, Object?>{'winter': '#FF6A00'},
          'width': 2.0,
        },
        'tiles': <Object?>[1, 2, 3],
        'strict': true,
      };
      final wire = wireArgumentsForServiceExtension(arguments);
      expect(
        wire['patch'],
        '{"canopyColors":{"winter":"#FF6A00"},"width":2.0}',
      );
      expect(wire['tiles'], '[1,2,3]');
      expect(wire['strict'], 'true');
      expect(wire['id'], 'material/grass');

      final coerced = coerceArgumentsForSchema(schema, wire);
      expect(coerced, arguments);
      expect(
        () => validateAgainstSchema(schema, coerced),
        returnsNormally,
      );
    });

    test('null encodes to empty text and stays absent', () {
      const schemaWithOptional = {
        'type': 'object',
        'properties': {
          'count': {'type': 'integer'},
        },
      };
      final wire = wireArgumentsForServiceExtension({'count': null});
      expect(wire['count'], '');
      final coerced = coerceArgumentsForSchema(schemaWithOptional, wire);
      expect(coerced.containsKey('count'), isFalse);
    });

    test('strings never double-encode', () {
      final wire = wireArgumentsForServiceExtension({
        'patch': '{"already": "json"}',
      });
      expect(wire['patch'], '{"already": "json"}');
    });
  });
}
