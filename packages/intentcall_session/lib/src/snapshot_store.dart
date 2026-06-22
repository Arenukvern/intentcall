// Copyright (c) 2025, IntentCall authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:from_json_to_json/from_json_to_json.dart';

import 'json_helpers.dart';
import 'safe_writes.dart';

/// File-backed JSON snapshot persistence with structural diff support.
///
/// This store deliberately knows nothing about command catalogs, transports,
/// live runtimes, or session connectors. Hosts build snapshot payloads and use
/// this class only for durable storage and comparison.
final class IntentSnapshotStore {
  IntentSnapshotStore({required this.snapshotsDir});

  final String snapshotsDir;

  Future<Map<String, Object?>> saveSnapshot({
    required final String id,
    required final Map<String, Object?> snapshot,
    final SafeWriteOptions writeOptions = const SafeWriteOptions(),
  }) async {
    final file = _fileFor(id);
    final writeResult = await SafeFileWriter.writeTextFile(
      path: file.path,
      content: const JsonEncoder.withIndent('  ').convert(snapshot),
      options: writeOptions,
    );

    return <String, Object?>{
      ...snapshot,
      'path': file.path,
      'writeResults': [writeResult.toJson()],
    };
  }

  Future<Map<String, Object?>> loadSnapshot(final String id) async {
    final file = _fileFor(id);
    if (!file.existsSync()) {
      throw ArgumentError('Snapshot not found: $id');
    }

    final raw = file.readAsStringSync();
    try {
      return jsonDecodeThrowableMap(raw).cast<String, Object?>();
    } on Object catch (error) {
      throw StateError('Invalid snapshot payload: $id ($error)');
    }
  }

  Future<List<Map<String, Object?>>> listSnapshots() async {
    final dir = io.Directory(snapshotsDir);
    if (!dir.existsSync()) {
      return const <Map<String, Object?>>[];
    }

    final entries =
        dir
            .listSync()
            .where(
              (final entity) =>
                  entity is io.File && entity.path.endsWith('.json'),
            )
            .cast<io.File>()
            .toList()
          ..sort((final a, final b) => a.path.compareTo(b.path));

    final snapshots = <Map<String, Object?>>[];
    for (final file in entries) {
      try {
        final raw = file.readAsStringSync();
        if (!verifyMapDecodability(raw.trim())) {
          continue;
        }
        final json = jsonObjectOrEmpty(raw);
        snapshots.add({
          'id': jsonDecodeString(json['id']),
          'createdAt': json['createdAt'],
          'path': file.path,
        });
      } on Exception {
        // Skip unreadable files.
      }
    }

    return snapshots;
  }

  Future<Map<String, Object?>> diffSnapshots({
    required final String fromId,
    required final String toId,
  }) async {
    final from = await loadSnapshot(fromId);
    final to = await loadSnapshot(toId);

    final changes = <Map<String, Object?>>[];
    _diffNode(path: r'$', left: from, right: to, out: changes);

    final summary = <String, Object?>{
      'totalChanges': changes.length,
      'added': changes
          .where((final change) => change['type'] == 'added')
          .length,
      'removed': changes
          .where((final change) => change['type'] == 'removed')
          .length,
      'changed': changes
          .where((final change) => change['type'] == 'changed')
          .length,
      'typeChanged': changes
          .where((final change) => change['type'] == 'type_changed')
          .length,
    };

    return {'from': fromId, 'to': toId, 'summary': summary, 'changes': changes};
  }

  io.File _fileFor(final String id) {
    final safe = id.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
    return io.File('$snapshotsDir/$safe.json');
  }

  static void _diffNode({
    required final String path,
    required final Object? left,
    required final Object? right,
    required final List<Map<String, Object?>> out,
  }) {
    if (left == null && right == null) {
      return;
    }

    if (left == null) {
      out.add({'path': path, 'type': 'added', 'after': right});
      return;
    }

    if (right == null) {
      out.add({'path': path, 'type': 'removed', 'before': left});
      return;
    }

    if (left is Map && right is Map) {
      final leftMap = left.cast<String, Object?>();
      final rightMap = right.cast<String, Object?>();
      final allKeys = <String>{...leftMap.keys, ...rightMap.keys}.toList()
        ..sort();

      for (final key in allKeys) {
        _diffNode(
          path: '$path.$key',
          left: leftMap[key],
          right: rightMap[key],
          out: out,
        );
      }
      return;
    }

    if (left is List && right is List) {
      final maxLen = left.length > right.length ? left.length : right.length;
      for (var i = 0; i < maxLen; i += 1) {
        final nextLeft = i < left.length ? left[i] : null;
        final nextRight = i < right.length ? right[i] : null;
        _diffNode(
          path: '$path[$i]',
          left: nextLeft,
          right: nextRight,
          out: out,
        );
      }
      return;
    }

    if (left.runtimeType != right.runtimeType) {
      out.add({
        'path': path,
        'type': 'type_changed',
        'beforeType': left.runtimeType.toString(),
        'afterType': right.runtimeType.toString(),
        'before': left,
        'after': right,
      });
      return;
    }

    if (_jsonEquals(left, right)) {
      return;
    }

    out.add({'path': path, 'type': 'changed', 'before': left, 'after': right});
  }

  static bool _jsonEquals(final Object? left, final Object? right) {
    try {
      return jsonEncode(left) == jsonEncode(right);
    } on Object {
      return left == right;
    }
  }
}
