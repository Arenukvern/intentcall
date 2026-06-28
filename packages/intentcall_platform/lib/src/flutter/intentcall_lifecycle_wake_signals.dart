import 'dart:async';

import 'package:flutter/widgets.dart';

import 'intentcall_host_events.dart';

/// Flutter lifecycle wake source for foreground/resume dispatch.
final class IntentCallLifecycleWakeSignals with WidgetsBindingObserver {
  IntentCallLifecycleWakeSignals() {
    WidgetsBinding.instance.addObserver(this);
  }

  final StreamController<IntentCallDrainTrigger> _controller =
      StreamController<IntentCallDrainTrigger>.broadcast();

  Stream<IntentCallDrainTrigger> get resumeSignals => _controller.stream;

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_controller.isClosed) {
      _controller.add(IntentCallDrainTrigger.resume);
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _controller.close();
  }
}
