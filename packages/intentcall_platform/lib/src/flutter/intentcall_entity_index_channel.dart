import 'package:flutter/services.dart';

const _channel = MethodChannel('intentcall_platform/entities');

Future<Object?> defaultIntentCallPlatformEntityInvoke(
  final String method,
  final Object? arguments,
) => _channel.invokeMethod<Object?>(method, arguments);
