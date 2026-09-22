import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform_sync/io.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:path/path.dart' as p;

/// How `intentcall mcp serve` should attach.
enum McpServeKind { empty, link, vm, status }

final class McpServePlan {
  const McpServePlan._({
    required this.kind,
    this.announcement,
    this.vmServiceUri,
    this.statusMessage = '',
  });

  const McpServePlan.empty() : this._(kind: McpServeKind.empty);

  const McpServePlan.link(final AgentLinkAnnouncement announcement)
    : this._(kind: McpServeKind.link, announcement: announcement);

  const McpServePlan.vm(final Uri vmServiceUri)
    : this._(kind: McpServeKind.vm, vmServiceUri: vmServiceUri);

  const McpServePlan.status(final String statusMessage)
    : this._(kind: McpServeKind.status, statusMessage: statusMessage);

  final McpServeKind kind;
  final AgentLinkAnnouncement? announcement;
  final Uri? vmServiceUri;
  final String statusMessage;
}

Future<McpServePlan> planMcpServe({
  required final bool auto,
  required final String scheme,
  required final AgentLinkDirectory directory,
  final Uri? vmServiceUri,
  final Future<Uri?> Function()? discoverVm,
}) async {
  if (vmServiceUri != null) {
    return McpServePlan.vm(vmServiceUri);
  }
  if (auto) {
    final discovered = await (discoverVm ?? discoverFlutterVmServiceUri)();
    if (discovered != null) {
      return McpServePlan.vm(discovered);
    }
  }
  if (scheme.isNotEmpty) {
    final found = await directory.find(scheme);
    if (found != null) {
      return McpServePlan.link(found);
    }
    if (!auto) {
      return McpServePlan.status(
        'No live IntentCall link for scheme "$scheme".',
      );
    }
  }
  if (auto) {
    final target = scheme.isEmpty ? 'this project' : 'scheme "$scheme"';
    return McpServePlan.status(
      'No debug VM and no live link for $target. '
      'Run the Flutter or Jaspr app, or pass --vm-service-uri.',
    );
  }
  return const McpServePlan.empty();
}

InMemoryAgentRegistry statusRegistry(final String message) =>
    InMemoryAgentRegistry()..register(
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'intentcall',
          name: 'app_status',
          description:
              'Reports whether a debug VM or a published app link is available.',
          kind: AgentIntentKind.tool,
          inputSchema: const <String, Object?>{'type': 'object'},
        ),
        execute: (final _) async => AgentResult.success(
          data: <String, Object?>{'running': false, 'message': message},
        ),
      ),
    );

/// Reads one `flutter attach --machine` line and returns a VM service URI.
Uri? parseFlutterMachineVmUri(final String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    final found = _findWsUri(decoded);
    if (found != null) {
      return found;
    }
  } on FormatException {
    // Fall through to a raw URI search.
  }
  final match = RegExp(r'wss?://[^\s"\\\]]+').firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  return Uri.tryParse(match.group(0)!);
}

Uri? _findWsUri(final Object? value) {
  if (value is String) {
    if (value.startsWith('ws://') || value.startsWith('wss://')) {
      return Uri.tryParse(value);
    }
    return null;
  }
  if (value is Map) {
    for (final entry in value.values) {
      final found = _findWsUri(entry);
      if (found != null) {
        return found;
      }
    }
  }
  if (value is List) {
    for (final entry in value) {
      final found = _findWsUri(entry);
      if (found != null) {
        return found;
      }
    }
  }
  return null;
}

Future<Uri?> discoverFlutterVmServiceUri({
  final Duration budget = const Duration(seconds: 2),
  final String flutterExecutable = 'flutter',
}) async {
  final Process process;
  try {
    process = await Process.start(flutterExecutable, const <String>[
      'attach',
      '--machine',
    ]);
  } on ProcessException {
    return null;
  }
  final completer = Completer<Uri?>();
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((final line) {
        final uri = parseFlutterMachineVmUri(line);
        if (uri != null && !completer.isCompleted) {
          completer.complete(uri);
        }
      });
  final result = await completer.future.timeout(budget, onTimeout: () => null);
  process.kill();
  return result;
}

/// Launch descriptor for the Flutter MCP toolkit debug door.
final class FlutterMcpLaunch {
  const FlutterMcpLaunch({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

FlutterMcpLaunch? resolveFlutterMcpLaunch({
  required final Uri vmServiceUri,
  final String? toolkitDir,
}) {
  final dir = toolkitDir ?? _defaultToolkitDir();
  if (dir == null) {
    return null;
  }
  final entry = File(p.join(dir, 'bin', 'flutter_mcp_toolkit.dart'));
  if (!entry.existsSync()) {
    return null;
  }
  return FlutterMcpLaunch(
    executable: Platform.resolvedExecutable,
    arguments: <String>[
      entry.path,
      '--vm-service-uri',
      vmServiceUri.toString(),
    ],
    workingDirectory: dir,
  );
}

String? _defaultToolkitDir() {
  final fromEnv = Platform.environment['FLUTTER_MCP_TOOLKIT_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  final fromScript = p.normalize(
    p.join(
      p.dirname(Platform.script.toFilePath()),
      '..',
      '..',
      '..',
      '..',
      'mcp_flutter',
      'mcp_server_dart',
    ),
  );
  if (File(p.join(fromScript, 'bin', 'flutter_mcp_toolkit.dart')).existsSync()) {
    return fromScript;
  }
  return null;
}
