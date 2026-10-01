import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _bannedSchemePrefix = 'intentcall://';

void main() {
  group('manifest resource URI policy', () {
    test('derived resourceUri uses app protocolScheme', () {
      const merger = ManifestMerger();
      const policy = ProjectionPolicy();
      final manifest = merger.mergeManifest(
        catalog: [
          AgentRegistryCatalogEntry(
            registryKey: 'app_runtime_snapshot',
            descriptor: AgentIntentDescriptor(
              namespace: 'app',
              name: 'runtime_snapshot',
              description: 'Runtime snapshot',
              kind: AgentIntentKind.resource,
              inputSchema: const <String, Object?>{'type': 'object'},
            ),
          ),
        ],
        policy: policy,
        protocolScheme: 'demoapp',
      );

      expect(manifest.protocolScheme, 'demoapp');
      expect(
        manifest.entries.single.resourceUri,
        'demoapp://resource/runtime/snapshot',
      );
    });

    test('explicit resourceUri is preserved during export', () {
      const merger = ManifestMerger();
      const policy = ProjectionPolicy();
      const explicitUri = 'visual://localhost/app/runtime/snapshot';
      final manifest = merger.mergeManifest(
        catalog: [
          AgentRegistryCatalogEntry(
            registryKey: 'app_runtime_snapshot',
            descriptor: AgentIntentDescriptor(
              namespace: 'app',
              name: 'runtime_snapshot',
              description: 'Runtime snapshot',
              kind: AgentIntentKind.resource,
              inputSchema: const <String, Object?>{'type': 'object'},
              resourceUri: explicitUri,
            ),
          ),
        ],
        policy: policy,
        protocolScheme: 'demoapp',
      );

      expect(manifest.entries.single.resourceUri, explicitUri);
    });

    test('encoded manifest export never emits intentcall://', () {
      const merger = ManifestMerger();
      const policy = ProjectionPolicy();
      final encoded = merger.encodeManifest(
        merger.mergeManifest(
          catalog: [
            AgentRegistryCatalogEntry(
              registryKey: 'app_runtime_snapshot',
              descriptor: AgentIntentDescriptor(
                namespace: 'app',
                name: 'runtime_snapshot',
                description: 'Runtime snapshot',
                kind: AgentIntentKind.resource,
                inputSchema: const <String, Object?>{'type': 'object'},
              ),
            ),
            AgentRegistryCatalogEntry(
              registryKey: 'app_ping',
              descriptor: AgentIntentDescriptor(
                namespace: 'app',
                name: 'ping',
                description: 'Ping',
                kind: AgentIntentKind.tool,
                inputSchema: const <String, Object?>{'type': 'object'},
              ),
            ),
          ],
          policy: policy,
          protocolScheme: 'demoapp',
        ),
      );

      expect(encoded, isNot(contains(_bannedSchemePrefix)));
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      _assertNoBannedScheme(decoded);
    });

    test('committed agent_manifest.json fixtures never emit intentcall://', () {
      final repoRoot = _repoRoot();
      final manifests = [
        p.join(
          repoRoot,
          'packages/intentcall_cli/test/fixtures/flutter_project/web/agent_manifest.json',
        ),
        p.join(
          repoRoot,
          'packages/intentcall_cli/test/fixtures/jaspr_web_project/web/agent_manifest.json',
        ),
        p.join(
          repoRoot,
          'packages/intentcall_cli/test/fixtures/codegen_dart_project/web/agent_manifest.json',
        ),
        p.join(
          repoRoot,
          'packages/intentcall_codegen/example/web/agent_manifest.json',
        ),
      ];

      for (final manifestPath in manifests) {
        final file = File(manifestPath);
        expect(file.existsSync(), isTrue, reason: manifestPath);
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains(_bannedSchemePrefix)),
          reason: manifestPath,
        );

        final manifest = AgentManifest.parse(source);
        _assertDerivedResourceUrisUseProtocolScheme(manifest);
      }
    });
  });
}

String _repoRoot() {
  var dir = Directory.current;
  while (!File(p.join(dir.path, 'steward.yaml')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repository root from ${dir.path}');
    }
    dir = parent;
  }
  return dir.path;
}

void _assertNoBannedScheme(final Object? value) {
  if (value is String) {
    expect(value, isNot(contains(_bannedSchemePrefix)));
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      _assertNoBannedScheme(entry.key);
      _assertNoBannedScheme(entry.value);
    }
    return;
  }
  if (value is List) {
    value.forEach(_assertNoBannedScheme);
  }
}

void _assertDerivedResourceUrisUseProtocolScheme(final AgentManifest manifest) {
  final scheme = manifest.protocolScheme?.trim() ?? '';
  if (scheme.isEmpty) {
    return;
  }

  for (final entry in manifest.entries) {
    if (entry.kind != AgentIntentKind.resource) {
      continue;
    }
    final resourceUri = entry.resourceUri?.trim() ?? '';
    if (resourceUri.isEmpty) {
      continue;
    }
    expect(
      resourceUri,
      isNot(startsWith(_bannedSchemePrefix)),
      reason: entry.qualifiedName,
    );

    final descriptor = entry.toDescriptor();
    if (descriptor.resourceUri != null) {
      continue;
    }

    expect(
      resourceUri,
      descriptor.effectiveResourceUri(scheme),
      reason: entry.qualifiedName,
    );
    expect(
      resourceUri,
      startsWith('$scheme://resource/'),
      reason: entry.qualifiedName,
    );
  }
}
