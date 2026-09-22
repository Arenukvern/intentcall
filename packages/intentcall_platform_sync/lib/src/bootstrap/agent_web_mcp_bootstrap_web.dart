import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import '../invocation/intentcall_invocation.dart';
import '../projection/manifest_surface_index.dart';
import 'web_mcp_registration_report.dart';

/// Browser-visible failure for a WebMCP `execute` promise.
final class WebMcpToolExecutionException implements Exception {
  WebMcpToolExecutionException({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => 'WebMcpToolExecutionException($code): $message';
}

@JS('JSON.parse')
external JSAny? _jsonParse(final JSString source);

/// Tool names already published to WebMCP by the Dart bootstrap.
final _webMcpRegisteredToolNames = <String>{};

/// Entries available to [__intentcallWebMcpDartExecute] when JS registered first.
final _entriesByQualifiedName = <String, AgentCallEntry>{};
final _entryPoliciesByQualifiedName = <String, IntentCallAuthorizationPolicy>{};
final _bridgesByQualifiedName = <String, IntentCallNativeBridge>{};

var _dartExecuteHookInstalled = false;

/// Whether [qualifiedName] was registered by [registerFromEntries].
///
/// Used by dogfood [WebMcpPublishAdapter] to avoid triple registration when
/// generated JS bootstrap and Dart bootstrap both run (see web eval doc).
bool isAgentWebMcpToolRegistered(final String qualifiedName) =>
    _webMcpRegisteredToolNames.contains(qualifiedName);

extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external void abort();
  external JSObject get signal;
}

extension type _RegisterOptions._(JSObject _) implements JSObject {
  external factory _RegisterOptions({final JSObject signal});
}

extension type _ModelContext._(JSObject _) implements JSObject {
  external JSAny? registerTool(
    final _WebMcpToolDefinition toolDefinition,
    final _RegisterOptions options,
  );
}

final _controllers = <String, _AbortController>{};

extension type _WebMcpToolDefinition._(JSObject _) implements JSObject {
  external factory _WebMcpToolDefinition({
    final JSString name,
    final JSString description,
    final JSAny inputSchema,
    final JSFunction execute,
  });
}

/// Registers tools on `document.modelContext` after [MCPToolkitExtensions.addEntries].
///
/// Older browser experiments exposed `navigator.modelContext`; that path is
/// retained as a compatibility fallback.
///
/// `web/intentcall_webmcp.generated.js` may register the same names before Flutter
/// loads. Those handlers run JS `validateInput`, then delegate to
/// [globalContext]'s `__intentcallWebMcpDartExecute` when this bootstrap installs
/// it (full [AgentCallEntry.invokeDirect] validation). If no Dart entry exists,
/// generated JS returns `runtime_unavailable` unless network fallback was
/// explicitly enabled.
WebMcpRegistrationReport registerFromEntries(
  final Set<AgentCallEntry> entries, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return WebMcpRegistrationReport.unavailable(
      skipped: [
        for (final entry in entries)
          if (entry.toRegistration().descriptor.kind == AgentIntentKind.tool)
            entry.toRegistration().descriptor.qualifiedName,
      ],
    );
  }

  _ensureDartExecuteHook();
  final registered = <String>[];
  final skipped = <String>[];

  for (final entry in entries) {
    final descriptor = entry.toRegistration().descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }

    final qualifiedName = descriptor.qualifiedName;
    if (!_includesWebMcp(qualifiedName, surfaceIndex)) {
      continue;
    }
    _entriesByQualifiedName[qualifiedName] = entry;
    _entryPoliciesByQualifiedName[qualifiedName] = policy;
    if (_registerTool(
      modelContext,
      qualifiedName: qualifiedName,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      execute: (final rawArgs) => _invokeEntry(entry, qualifiedName, rawArgs),
    )) {
      registered.add(qualifiedName);
    } else {
      skipped.add(qualifiedName);
    }
  }
  return WebMcpRegistrationReport(
    available: true,
    registered: registered,
    skipped: skipped,
  );
}

WebMcpRegistrationReport registerFromRegistry(
  final AgentRegistry registry, {
  required final IntentCallAuthorizationPolicy policy,
  final ManifestSurfaceIndex? surfaceIndex,
}) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return WebMcpRegistrationReport.unavailable(
      skipped: [
        for (final entry in registry.listEntries())
          if (entry.descriptor.kind == AgentIntentKind.tool) entry.key,
      ],
    );
  }

  _ensureDartExecuteHook();
  final bridge = IntentCallNativeBridge.bindRegistry(
    registry: registry,
    policy: policy,
  );
  final registered = <String>[];
  final skipped = <String>[];

  for (final entry in registry.listEntries()) {
    final descriptor = entry.descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }
    final qualifiedName = entry.key;
    if (!_includesWebMcp(qualifiedName, surfaceIndex)) {
      continue;
    }
    _bridgesByQualifiedName[qualifiedName] = bridge;
    if (_registerTool(
      modelContext,
      qualifiedName: qualifiedName,
      description: descriptor.description,
      inputSchema: descriptor.inputSchema,
      execute: (final rawArgs) => _invokeBridge(bridge, qualifiedName, rawArgs),
    )) {
      registered.add(qualifiedName);
    } else {
      skipped.add(qualifiedName);
    }
  }
  _watchRegistry(
    registry,
    modelContext: modelContext,
    bridge: bridge,
    surfaceIndex: surfaceIndex,
  );
  return WebMcpRegistrationReport(
    available: true,
    registered: registered,
    skipped: skipped,
  );
}

StreamSubscription<AgentRegistryEvent>? _registryEvents;

void _watchRegistry(
  final AgentRegistry registry, {
  required final _ModelContext modelContext,
  required final IntentCallNativeBridge bridge,
  required final ManifestSurfaceIndex? surfaceIndex,
}) {
  final previous = _registryEvents;
  if (previous != null) {
    unawaited(previous.cancel());
  }
  _registryEvents = registry.events.listen((final event) {
    switch (event) {
      case IntentRegistered(:final qualifiedName):
        final intent = registry.get(qualifiedName);
        if (intent == null ||
            intent.descriptor.kind != AgentIntentKind.tool ||
            !_includesWebMcp(qualifiedName, surfaceIndex)) {
          return;
        }
        _bridgesByQualifiedName[qualifiedName] = bridge;
        _registerTool(
          modelContext,
          qualifiedName: qualifiedName,
          description: intent.descriptor.description,
          inputSchema: intent.descriptor.inputSchema,
          execute: (final rawArgs) =>
              _invokeBridge(bridge, qualifiedName, rawArgs),
        );
      case IntentUnregistered(:final qualifiedName):
        _abortPrevious(qualifiedName);
        _bridgesByQualifiedName.remove(qualifiedName);
      case EntityTypeRegistered() || EntityTypeUnregistered():
        break;
    }
  });
}

bool _registerTool(
  final _ModelContext modelContext, {
  required final String qualifiedName,
  required final String description,
  required final Map<String, Object?> inputSchema,
  required final Future<JSAny?> Function(JSAny? rawArgs) execute,
}) {
  _abortPrevious(qualifiedName);
  final controller = _AbortController();
  final toolDefinition = _WebMcpToolDefinition(
    name: qualifiedName.toJS,
    description: description.toJS,
    inputSchema: _jsonParse(jsonEncode(inputSchema).toJS)!,
    execute: ((final JSAny? rawArgs) => execute(rawArgs).toJS).toJS,
  );
  try {
    modelContext.registerTool(
      toolDefinition,
      _RegisterOptions(signal: controller.signal),
    );
    _controllers[qualifiedName] = controller;
    _webMcpRegisteredToolNames.add(qualifiedName);
    return true;
  } on Object {
    controller.abort();
    return false;
  }
}

void _abortPrevious(final String qualifiedName) {
  _controllers.remove(qualifiedName)?.abort();
  final abort = globalContext.getProperty('__intentcallWebMcpAbort'.toJS);
  if (abort != null) {
    (abort as JSFunction).callAsFunction(null, qualifiedName.toJS);
  }
  _webMcpRegisteredToolNames.remove(qualifiedName);
}

void _ensureDartExecuteHook() {
  if (_dartExecuteHookInstalled) {
    return;
  }
  _dartExecuteHookInstalled = true;
  globalContext.setProperty(
    '__intentcallWebMcpDartExecute'.toJS,
    ((final JSString nameJS, final JSAny? rawArgs) => _dartExecuteHook(
      nameJS,
      rawArgs,
    ).toJS).toJS,
  );
}

Future<JSAny?> _dartExecuteHook(
  final JSString nameJS,
  final JSAny? rawArgs,
) async {
  final qualifiedName = nameJS.toDart;
  final bridge = _bridgesByQualifiedName[qualifiedName];
  if (bridge != null) {
    return _invokeBridge(bridge, qualifiedName, rawArgs);
  }
  final entry = _entriesByQualifiedName[qualifiedName];
  if (entry == null) {
    return null;
  }
  return _invokeEntry(entry, qualifiedName, rawArgs);
}

_ModelContext? _readModelContext() =>
    _readModelContextFromGlobalObject('document') ??
    _readModelContextFromGlobalObject('navigator');

_ModelContext? _readModelContextFromGlobalObject(final String name) {
  final owner = globalContext.getProperty(name.toJS);
  if (owner == null) {
    return null;
  }
  final object = owner as JSObject;
  if (!object.hasProperty('modelContext'.toJS).toDart) {
    return null;
  }
  final value = object.getProperty('modelContext'.toJS);
  if (value == null) {
    return null;
  }
  return value as _ModelContext;
}

Future<JSAny?> _invokeEntry(
  final AgentCallEntry entry,
  final String qualifiedName,
  final JSAny? rawArgs,
) async {
  final args = _decodeArgs(rawArgs);
  final envelope = IntentCallInvocationEnvelope(
    id: 'webmcp-${DateTime.now().microsecondsSinceEpoch}',
    qualifiedName: qualifiedName,
    arguments: args,
    source: IntentCallInvocationSource.webMcpDart,
  );
  final policy =
      _entryPoliciesByQualifiedName[qualifiedName] ??
      const IntentCallAuthorizationPolicy.denyAll();
  if (!await policy.allows(envelope)) {
    return _reject(
      AgentResult.failure(
        code: 'invocation_denied',
        message: 'Invocation denied for $qualifiedName.',
        details: <String, Object?>{'source': envelope.source},
      ),
    );
  }
  return _reject(await entry.invokeDirect(args));
}

Future<JSAny?> _invokeBridge(
  final IntentCallNativeBridge bridge,
  final String qualifiedName,
  final JSAny? rawArgs,
) async {
  final args = _decodeArgs(rawArgs);
  final result = await bridge.execute(
    IntentCallInvocationEnvelope(
      id: 'webmcp-${DateTime.now().microsecondsSinceEpoch}',
      qualifiedName: qualifiedName,
      arguments: args,
      source: IntentCallInvocationSource.webMcpDart,
    ),
  );
  return _reject(result);
}

Future<JSAny?> _reject(final AgentResult result) async {
  if (!result.ok) {
    throw WebMcpToolExecutionException(
      code: result.code ?? 'tool_failed',
      message: result.message,
      details: result.details,
    );
  }
  return _encodeResult(result).jsify();
}

Map<String, Object?> _decodeArgs(final JSAny? rawArgs) {
  if (rawArgs == null) {
    return const <String, Object?>{};
  }
  final decoded = jsonDecode(jsonEncode(rawArgs.dartify()));
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

Map<String, Object?> _encodeResult(final AgentResult result) {
  if (!result.ok) {
    return <String, Object?>{
      'ok': false,
      'code': result.code,
      'message': result.message,
      if (result.details.isNotEmpty) 'details': result.details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}

bool _includesWebMcp(
  final String qualifiedName,
  final ManifestSurfaceIndex? surfaceIndex,
) {
  if (surfaceIndex == null) {
    return true;
  }
  return surfaceIndex.includesWebMcp(qualifiedName);
}
