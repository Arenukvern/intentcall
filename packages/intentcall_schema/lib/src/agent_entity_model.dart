import 'package:meta/meta.dart';

/// Stable identity for an indexable app object exposed to agents.
///
/// The triple `(namespace, typeName, identifier)` must be unique within an app.
/// Agents use refs to open, update, or reference entities across transports.
///
/// ## Wire JSON (AX)
///
/// ```json
/// {
///   "namespace": "notes",
///   "type_name": "note",
///   "identifier": "note-1"
/// }
/// ```
@immutable
final class AgentEntityRef {
  /// Creates a reference with the given [namespace], [typeName], and [identifier].
  ///
  /// All three strings must be non-empty when parsed from JSON.
  const AgentEntityRef({
    required this.namespace,
    required this.typeName,
    required this.identifier,
  });

  /// Parses [json] produced by [toJson].
  ///
  /// Throws [ArgumentError] when required fields are missing or empty.
  factory AgentEntityRef.fromJson(final Map<String, Object?> json) =>
      AgentEntityRef(
        namespace: _requiredString(json, 'namespace'),
        typeName: _requiredString(json, 'type_name'),
        identifier: _requiredString(json, 'identifier'),
      );

  /// App domain grouping entities (for example `notes`, `music`).
  final String namespace;

  /// Entity kind within [namespace] (for example `note`, `playlist`).
  final String typeName;

  /// Stable id for this entity within ([namespace], [typeName]).
  final String identifier;

  /// Serializes to JSON using snake_case keys (`type_name`).
  Map<String, Object?> toJson() => <String, Object?>{
    'namespace': namespace,
    'type_name': typeName,
    'identifier': identifier,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AgentEntityRef &&
          namespace == other.namespace &&
          typeName == other.typeName &&
          identifier == other.identifier;

  @override
  int get hashCode => Object.hash(namespace, typeName, identifier);
}

/// JSON-safe snapshot of an app entity for search, shortcuts, and agent context.
///
/// [properties] holds domain fields agents may read or filter on. Display
/// fields (`title`, `subtitle`, `keywords`, …) support human and voice UIs.
/// Only JSON-encodable values are allowed in [properties] (`String`, `int`,
/// `double`, `bool`, `List`, and nested `Map` with string keys).
///
/// ## Wire JSON (AX)
///
/// See package README for the full shape. Use [toJson] / [fromJson] for
/// round-tripping across native stores, manifest export, and MCP resources.
///
/// ## Display
///
/// Prefer [effectiveTitle] when rendering a single line of text; it falls back
/// from [title] to [displayName].
@immutable
final class AgentEntitySnapshot {
  /// Creates a snapshot for [ref] with JSON-safe [properties].
  ///
  /// [keywords] entries are trimmed; empty strings throw [ArgumentError].
  /// [deleted] marks tombstones so indexes can remove stale entries.
  AgentEntitySnapshot({
    required this.ref,
    required final Map<String, Object?> properties,
    this.title,
    this.subtitle,
    final Iterable<String> keywords = const <String>[],
    this.thumbnailUrl,
    this.url,
    this.displayName,
    this.deepLink,
    this.updatedAt,
    this.deleted = false,
    this.version,
    this.freshness,
  }) : keywords = List<String>.unmodifiable(
         keywords.map((final value) {
           final trimmed = value.trim();
           if (trimmed.isEmpty) {
             throw ArgumentError.value(value, 'keywords', 'Expected text.');
           }
           return trimmed;
         }),
       ),
       properties = _jsonObject(properties);

  /// Parses [json] produced by [toJson].
  ///
  /// Throws [ArgumentError] when `ref` or `properties` are not objects, or when
  /// nested values are not JSON-safe.
  factory AgentEntitySnapshot.fromJson(final Map<String, Object?> json) {
    final rawRef = json['ref'];
    if (rawRef is! Map) {
      throw ArgumentError.value(rawRef, 'ref', 'Expected a JSON object.');
    }
    final rawProperties = json['properties'];
    if (rawProperties is! Map) {
      throw ArgumentError.value(
        rawProperties,
        'properties',
        'Expected a JSON object.',
      );
    }
    return AgentEntitySnapshot(
      ref: AgentEntityRef.fromJson(Map<String, Object?>.from(rawRef)),
      properties: _jsonObject(Map<String, Object?>.from(rawProperties)),
      title: _optionalString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
      keywords: _optionalStringList(json, 'keywords'),
      thumbnailUrl: _optionalString(json, 'thumbnail_url'),
      url: _optionalString(json, 'url'),
      displayName: _optionalString(json, 'display_name'),
      deepLink: _optionalString(json, 'deep_link'),
      updatedAt: _optionalDateTime(json, 'updated_at'),
      deleted: _optionalBool(json, 'deleted') ?? false,
      version: _optionalString(json, 'version'),
      freshness: _optionalString(json, 'freshness'),
    );
  }

  /// Identity of this entity.
  final AgentEntityRef ref;

  /// Domain-specific JSON-safe fields (scalars, lists, nested maps).
  final Map<String, Object?> properties;

  /// Primary display title.
  final String? title;

  /// Secondary display line.
  final String? subtitle;

  /// Search keywords (non-empty, trimmed).
  final List<String> keywords;

  /// Thumbnail image URL.
  final String? thumbnailUrl;

  /// Canonical web or app URL for this entity.
  final String? url;

  /// Alternate display name when [title] is absent.
  final String? displayName;

  /// Platform deep link or custom scheme URI to open this entity.
  final String? deepLink;

  /// Last modification time (serialized as UTC ISO-8601).
  final DateTime? updatedAt;

  /// When `true`, indexes should treat this snapshot as a tombstone.
  final bool deleted;

  /// Opaque revision or etag for change detection.
  final String? version;

  /// Hint for staleness (for example `fresh`, `stale`); adapter-defined.
  final String? freshness;

  /// [title] if set, otherwise [displayName].
  String? get effectiveTitle => title ?? displayName;

  /// Serializes to JSON using snake_case keys.
  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref.toJson(),
    'properties': properties,
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (keywords.isNotEmpty) 'keywords': keywords,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (url != null) 'url': url,
    if (displayName != null) 'display_name': displayName,
    if (deepLink != null) 'deep_link': deepLink,
    if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    if (deleted) 'deleted': true,
    if (version != null) 'version': version,
    if (freshness != null) 'freshness': freshness,
  };

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AgentEntitySnapshot &&
          ref == other.ref &&
          title == other.title &&
          subtitle == other.subtitle &&
          _jsonEquals(keywords, other.keywords) &&
          thumbnailUrl == other.thumbnailUrl &&
          url == other.url &&
          displayName == other.displayName &&
          deepLink == other.deepLink &&
          updatedAt == other.updatedAt &&
          deleted == other.deleted &&
          version == other.version &&
          freshness == other.freshness &&
          _jsonEquals(properties, other.properties);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    ref,
    title,
    subtitle,
    _jsonHash(keywords),
    thumbnailUrl,
    url,
    displayName,
    deepLink,
    updatedAt,
    deleted,
    version,
    freshness,
    _jsonHash(properties),
  ]);
}

String _requiredString(final Map<String, Object?> json, final String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw ArgumentError.value(value, key, 'Expected a non-empty string.');
}

String? _optionalString(final Map<String, Object?> json, final String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw ArgumentError.value(value, key, 'Expected a string.');
}

List<String> _optionalStringList(
  final Map<String, Object?> json,
  final String key,
) {
  final value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw ArgumentError.value(value, key, 'Expected an array of strings.');
  }
  return List<String>.unmodifiable(
    value.map((final item) {
      if (item is String && item.trim().isNotEmpty) {
        return item.trim();
      }
      throw ArgumentError.value(item, key, 'Expected non-empty strings.');
    }),
  );
}

bool? _optionalBool(final Map<String, Object?> json, final String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw ArgumentError.value(value, key, 'Expected a boolean.');
}

DateTime? _optionalDateTime(final Map<String, Object?> json, final String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return DateTime.parse(value).toUtc();
  }
  throw ArgumentError.value(value, key, 'Expected an ISO-8601 string.');
}

Map<String, Object?> _jsonObject(final Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable(
      value.map((final key, final value) => MapEntry(key, _jsonValue(value))),
    );

Object? _jsonValue(final Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Expected a finite number.');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_jsonValue));
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((final key, final value) {
        if (key is! String) {
          throw ArgumentError.value(key, 'key', 'Expected a string key.');
        }
        return MapEntry(key, _jsonValue(value));
      }),
    );
  }
  throw ArgumentError.value(value, 'value', 'Expected a JSON-safe value.');
}

bool _jsonEquals(final Object? left, final Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_jsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (!_jsonEquals(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _jsonHash(final Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (final entry) => Object.hash(entry.key, _jsonHash(entry.value)),
      ),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_jsonHash));
  }
  return value.hashCode;
}
