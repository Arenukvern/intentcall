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
}
