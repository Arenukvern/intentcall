import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import '../invocation/intentcall_invocation.dart';

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

extension type _ModelContext._(JSObject _) implements JSObject {
  external void registerTool(final _WebMcpToolDefinition toolDefinition);
}

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
void registerFromEntries(
  final Set<AgentCallEntry> entries, {
  required final IntentCallAuthorizationPolicy policy,
}) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return;
  }

  _ensureDartExecuteHook();

  for (final entry in entries) {
    final descriptor = entry.toRegistration().descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }

    final qualifiedName = descriptor.qualifiedName;
    _entriesByQualifiedName[qualifiedName] = entry;
    _entryPoliciesByQualifiedName[qualifiedName] = policy;

    if (_webMcpRegisteredToolNames.contains(qualifiedName)) {
      continue;
    }
    final toolDefinition = _WebMcpToolDefinition(
      name: qualifiedName.toJS,
      description: descriptor.description.toJS,
      inputSchema: _jsonParse(jsonEncode(descriptor.inputSchema).toJS)!,
      execute: ((final JSAny? rawArgs) => _invokeEntry(
        entry,
        qualifiedName,
        rawArgs,
      ).toJS).toJS,
    );
    try {
      modelContext.registerTool(toolDefinition);
      _webMcpRegisteredToolNames.add(qualifiedName);
    } on Object {
      // Duplicate name (JS bootstrap registered first) — JS execute uses hook.
    }
  }
}

void registerFromRegistry(
  final AgentRegistry registry, {
  required final IntentCallAuthorizationPolicy policy,
}) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return;
  }

  _ensureDartExecuteHook();
  final bridge = IntentCallNativeBridge.bindRegistry(
    registry: registry,
    policy: policy,
  );

  for (final entry in registry.listEntries()) {
    final descriptor = entry.descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }
    final qualifiedName = entry.key;
    _bridgesByQualifiedName[qualifiedName] = bridge;

    if (_webMcpRegisteredToolNames.contains(qualifiedName)) {
      continue;
    }
    final toolDefinition = _WebMcpToolDefinition(
      name: qualifiedName.toJS,
      description: descriptor.description.toJS,
      inputSchema: _jsonParse(jsonEncode(descriptor.inputSchema).toJS)!,
      execute: ((final JSAny? rawArgs) => _invokeBridge(
        bridge,
        qualifiedName,
        rawArgs,
      ).toJS).toJS,
    );
    try {
      modelContext.registerTool(toolDefinition);
      _webMcpRegisteredToolNames.add(qualifiedName);
    } on Object {
      // Duplicate name (JS bootstrap registered first) — JS execute uses hook.
    }
  }
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
    return _encodeResult(
      AgentResult.failure(
        code: 'invocation_denied',
        message: 'Invocation denied for $qualifiedName.',
        details: <String, Object?>{'source': envelope.source},
      ),
    ).jsify();
  }
  final result = await entry.invokeDirect(args);
  return _encodeResult(result).jsify();
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
