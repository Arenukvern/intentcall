/// Best-effort recovery of Dart `toString()` text for [Map] and [List].
///
/// Flutter's service-extension binding delivers every extension parameter
/// as a string, so a complex argument arrives as `Map.toString()` text —
/// `{width: 2.0, color: 4294918846}` — which is not JSON. Senders that
/// pre-encode to JSON ([wireValueForServiceExtension]) make this recovery
/// unnecessary; the parser exists for old senders and direct VM calls.
///
/// The parser is deliberately conservative: it returns `null` on anything
/// it cannot attribute (unbalanced brackets, trailing junk) so callers can
/// fall back to passing the text through for an honest validation refusal.
/// Dart `toString()` output has no string escaping, so values containing
/// delimiters (`,`, `:`, brackets, quotes) are unrecoverable by design.
///
/// Recovered shapes:
/// - maps `{key: value, …}` and lists `[value, …]`, nested arbitrarily
/// - keywords `true`, `false`, `null`
/// - numbers (int / double, including negatives)
/// - quoted values (`'…'`, `"…"`, the first matching quote ends the value)
/// - bare values (anything read to the next delimiter, trimmed)
library;

/// Recovers a value from Dart `toString()` text, `null` on failure.
Object? tryDecodeDartLiteral(final String input) {
  final scanner = _Scanner(input);
  final (value, ok) = scanner.parseValue();
  if (!ok || !scanner.atEnd()) {
    return null;
  }
  return value;
}

/// Recovers a [Map] from Dart `toString()` text, `null` on failure.
Map<String, Object?>? tryDecodeDartMap(final String input) =>
    switch (tryDecodeDartLiteral(input)) {
      final Map<String, Object?> map => map,
      _ => null,
    };

/// Recovers a [List] from Dart `toString()` text, `null` on failure.
List<Object?>? tryDecodeDartList(final String input) =>
    switch (tryDecodeDartLiteral(input)) {
      final List<Object?> list => list,
      _ => null,
    };

/// One-pass recursive-descent scanner. Every parse step returns
/// `(value, ok)`; `ok == false` means malformed input, never an exception.
final class _Scanner {
  _Scanner(this._text);

  final String _text;
  int _index = 0;
  static const _delimiters = {',', '}', ']'};

  bool atEnd() {
    _skipWhitespace();
    return _index >= _text.length;
  }

  (Object?, bool) parseValue() {
    _skipWhitespace();
    if (_index >= _text.length) {
      return (null, false);
    }
    return switch (_text[_index]) {
      '{' => _parseMap(),
      '[' => _parseList(),
      "'" || '"' => _parseQuoted(_text[_index]),
      _ => _parseBare(),
    };
  }

  (Object?, bool) _parseMap() {
    _index++; // consume '{'
    final entries = <String, Object?>{};
    _skipWhitespace();
    if (_peekIs('}')) {
      _index++;
      return (entries, true);
    }
    while (true) {
      final (key, ok) = _parseKey();
      if (!ok || key is! String) {
        return (null, false);
      }
      _skipWhitespace();
      if (!_peekIs(':')) {
        return (null, false);
      }
      _index++;
      final (value, valueOk) = parseValue();
      if (!valueOk) {
        return (null, false);
      }
      entries[key] = value;
      final (closed, separatorOk) = _separator();
      if (!separatorOk) {
        return (null, false);
      }
      if (closed) {
        return (entries, true);
      }
    }
  }

  /// Map keys are bare scalars or quoted strings — containers refuse
  /// (a `toString()` map key is not a string-keyed JSON map). Bare keys
  /// stop at `:` so the separator stays the separator; bare VALUES keep
  /// reading through colons (e.g. `http://x` survives as a value).
  (Object?, bool) _parseKey() {
    _skipWhitespace();
    if (_index >= _text.length) {
      return (null, false);
    }
    return switch (_text[_index]) {
      '{' || '[' => (null, false),
      "'" || '"' => _parseQuoted(_text[_index]),
      _ => _parseBare(stopAtColon: true),
    };
  }

  (Object?, bool) _parseList() {
    _index++; // consume '['
    final items = <Object?>[];
    _skipWhitespace();
    if (_peekIs(']')) {
      _index++;
      return (items, true);
    }
    while (true) {
      final (value, ok) = parseValue();
      if (!ok) {
        return (null, false);
      }
      items.add(value);
      final (closed, separatorOk) = _separator();
      if (!separatorOk) {
        return (null, false);
      }
      if (closed) {
        return (items, true);
      }
    }
  }

  /// After an entry: `,` means more entries follow; the level's closing
  /// bracket means the collection is done. Tolerates a trailing comma.
  /// Returns `(collectionClosed, ok)`.
  (bool, bool) _separator() {
    _skipWhitespace();
    if (_index >= _text.length) {
      return (false, false);
    }
    switch (_text[_index]) {
      case ',':
        _index++;
        _skipWhitespace();
        if (_peekIs('}') || _peekIs(']')) {
          _index++;
          return (true, true);
        }
        return (false, true);
      case '}' || ']':
        _index++;
        return (true, true);
      default:
        return (false, false);
    }
  }

  (Object?, bool) _parseQuoted(final String quote) {
    _index++; // consume opening quote
    final start = _index;
    while (_index < _text.length && _text[_index] != quote) {
      _index++;
    }
    if (_index >= _text.length) {
      return (null, false);
    }
    final value = _text.substring(start, _index);
    _index++; // consume closing quote
    return (value, true);
  }

  (Object?, bool) _parseBare({final bool stopAtColon = false}) {
    final start = _index;
    while (_index < _text.length &&
        !_delimiters.contains(_text[_index]) &&
        !(stopAtColon && _text[_index] == ':')) {
      _index++;
    }
    final token = _text
        .substring(start, _index >= _text.length ? _text.length : _index)
        .trim();
    return _classifyBare(token);
  }

  (Object?, bool) _classifyBare(final String token) {
    if (token.isEmpty) {
      return (null, false);
    }
    switch (token) {
      case 'true':
        return (true, true);
      case 'false':
        return (false, true);
      case 'null':
        return (null, true);
    }
    final number = num.tryParse(token);
    if (number != null) {
      return (number, true);
    }
    return (token, true);
  }

  bool _peekIs(final String char) =>
      _index < _text.length && _text[_index] == char;

  void _skipWhitespace() {
    while (_index < _text.length && _isWhitespace(_text[_index])) {
      _index++;
    }
  }

  static bool _isWhitespace(final String char) =>
      char == ' ' || char == '\t' || char == '\n' || char == '\r';
}
