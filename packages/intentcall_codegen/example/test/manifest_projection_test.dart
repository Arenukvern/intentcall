import 'dart:io';

import '../lib/generated/agent_catalog.g.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String projectRoot;
  late ManifestExporter exporter;
  late ManifestExportContext context;

  setUpAll(() {
    projectRoot = p.normalize(p.join(Platform.script.toFilePath(), '..', '..'));
    exporter = const ManifestExporter();
    context = exporter.loadExportContext(projectRoot: projectRoot);
  });

  AgentManifest buildManifest() =>
      exporter.buildManifest(catalog: agentCatalogEntries, context: context);

  test('demo_cart respects @AgentProjection(web.webMcp: false)', () {
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

  test('codegen instance tool respects @AgentProjection(web.webMcp: true)', () {
    final manifest = buildManifest();
    final hostStatus = manifest.tools.singleWhere(
      (final tool) => tool.qualifiedName == 'app_demo_host_status',
    );

    expect(hostStatus.dispatchMode, AgentManifestDispatchMode.openApp);
    expect(
      hostStatus.surfaces.includes(
        AgentManifestSurface.webMcp,
        defaultValue: true,
      ),
      isTrue,
    );
  });
}
