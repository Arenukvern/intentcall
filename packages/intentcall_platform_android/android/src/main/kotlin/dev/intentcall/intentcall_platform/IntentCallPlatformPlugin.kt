package dev.intentcall.intentcall_platform

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Android stub for the Pigeon bridge; entity/invocation stores are iOS/macOS today. */
class IntentCallPlatformPlugin : FlutterPlugin {
  private val bridge = IntentCallPlatformBridgeStub()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    IntentCallInvocationsHostApi.setUp(binding.binaryMessenger, bridge)
    IntentCallEntitiesHostApi.setUp(binding.binaryMessenger, bridge)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    IntentCallInvocationsHostApi.setUp(binding.binaryMessenger, null)
    IntentCallEntitiesHostApi.setUp(binding.binaryMessenger, null)
  }
}

private class IntentCallPlatformBridgeStub :
  IntentCallInvocationsHostApi,
  IntentCallEntitiesHostApi {
  override fun takePendingInvocations(): List<IntentCallInvocationEnvelopeDto> =
    emptyList()

  override fun upsertEntitySnapshots(
    entityType: String,
    snapshots: List<Map<String?, Any?>>,
    keys: IntentCallEntityKeyBundle,
  ): Long = 0

  override fun deleteEntitySnapshots(
    entityType: String,
    ids: List<String>,
    keys: IntentCallEntityKeyBundle,
  ): Long = 0

  override fun clearEntityTypeSnapshots(entityType: String): Long = 0

  override fun listEntitySnapshots(entityType: String): List<Map<String?, Any?>> =
    emptyList()

  override fun searchEntitySnapshots(
    entityType: String,
    query: String,
    limit: Long,
    keys: IntentCallEntityKeyBundle,
  ): List<Map<String?, Any?>> = emptyList()

  override fun takePendingEntityOpens(): List<IntentCallEntityOpenEnvelopeDto> =
    emptyList()
}
