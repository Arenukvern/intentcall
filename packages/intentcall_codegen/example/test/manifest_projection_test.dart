import 'dart:io';

import '../lib/generated/agent_catalog.g.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _exampleProjectRoot() {
  final cwd = Directory.current.path;
  final candidates = <String>[
    p.normalize(p.join(cwd, 'packages', 'intentcall_codegen', 'example')),
    p.normalize(cwd),
  ];
  for (final candidate in candidates) {
    if (File(p.join(candidate, 'intentcall.yaml')).existsSync()) {
      return candidate;
    }
  }
  throw StateError('Could not locate intentcall_codegen example project root');
}

void main() {
  late String projectRoot;
  late ManifestExporter exporter;
  late ManifestExportContext context;

  setUpAll(() {
    projectRoot = _exampleProjectRoot();
    exporter = const ManifestExporter();
    context = exporter.loadExportContext(projectRoot: projectRoot);
  });

  AgentManifest buildManifest() =>
      exporter.buildManifest(catalog: agentCatalogEntries, context: context);

  test('demo_cart respects @AgentProjection(webMcp: false)', () {
    final manifest = buildManifest();
    final cart = manifest.tools.singleWhere(
      (final tool) => tool.qualifiedName == 'app_demo_cart',
    );

    expect(cart.dispatchMode, AgentManifestDispatchMode.openApp);
    expect(
      cart.surfaces.includes(AgentManifestSurface.webMcp, defaultValue: true),
      isFalse,
    );
  });

  test('handwritten instance-bound tools appear in manifest export', () {
    final manifest = buildManifest();
    final qualifiedNames = manifest.tools
        .map((final tool) => tool.qualifiedName)
        .toSet();

    expect(qualifiedNames, contains('app_demo_inbox'));
    expect(qualifiedNames, contains('app_demo_handwritten'));
  });

  test('codegen instance tool respects @AgentProjection(webMcp: true)', () {
    final manifest = buildManifest();
    final hostStatus = manifest.tools.singleWhere(
      (final tool) => tool.qualifiedName == 'app_demo_host_status',
    );

    expect(hostStatus.dispatchMode, AgentManifestDispatchMode.openApp);
    expect(
      hostStatus.surfaces.includes(AgentManifestSurface.webMcp, defaultValue: true),
      isTrue,
    );
  });

  test('handwritten inbox respects co-located inboxProjection', () {
    final manifest = buildManifest();
    final inbox = manifest.tools.singleWhere(
      (final tool) => tool.qualifiedName == 'app_demo_inbox',
    );

    expect(
      inbox.surfaces.includes(AgentManifestSurface.webMcp, defaultValue: false),
      isTrue,
    );
  });

  test('web-only example disables non-web default surfaces', () {
    expect(context.enabledPlatforms, contains('web'));

    final manifest = buildManifest();
    final ping = manifest.tools.singleWhere(
      (final tool) => tool.qualifiedName == 'app_demo_ping',
    );

    expect(
      ping.surfaces.includes(AgentManifestSurface.webMcp, defaultValue: false),
      isTrue,
    );
    expect(
      ping.surfaces.includes(
        AgentManifestSurface.androidShortcuts,
        defaultValue: true,
      ),
      isFalse,
    );
    expect(
      ping.surfaces.includes(
        AgentManifestSurface.windowsProtocolActivation,
        defaultValue: true,
      ),
      isFalse,
    );
  });
}
