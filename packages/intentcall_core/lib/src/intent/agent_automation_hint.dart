import 'package:meta/meta.dart';

/// What an invocation layer should ask the driver to do.
///
/// Declarative on purpose: the hint names the driver verb; the runtime
/// arguments (text to type, expression to evaluate, destination route)
/// travel with the invocation, not the registration.
enum IntentAutomationAction {
  /// Resolve the locator and click/tap it.
  click,

  /// Focus the locator and type the invocation's text into it.
  type,

  /// Press the key named by the locator (`key`) or the invocation text.
  key,

  /// Navigate the surface to the locator (`route`) or invocation text.
  navigate,

  /// Evaluate the read-only expression from the invocation text.
  evaluate,

  /// Invoke the named surface action from the driver's action catalog.
  ///
  /// The locator carries the catalog name under `name`; the invocation's
  /// `args` map travels with the invocation (JSON-encodable). Catalog
  /// actions are how an intent drives framework- or app-specific verbs —
  /// a checkout flow, a Jaspr component contract — without waiting for a
  /// driver release to grow the universal verb set.
  custom;

  /// Parses [value] (wire form); `null` when it names no action.
  static IntentAutomationAction? tryParse(final Object? value) {
    for (final action in values) {
      if (action.name == value) return action;
    }
    return null;
  }

  /// Wire form.
  String get wire => name;
}

/// A driver-routing hint an intent may declare (ADR 0038).
///
/// IntentCall stays the intent/truth layer — it does not grow drivers.
/// This hint only records *how an `AutomationDriver` could execute the
/// intent*: which driver transport to pick, which verb to invoke, and
/// which locator to resolve against that driver's semantic snapshot.
/// Invocation layers (harness scenarios, CLI bridges) read it from the
/// descriptor and choose to route; IntentCall itself never drives.
@immutable
final class IntentAutomationHint {
  /// Creates a hint after validating its invariants.
  IntentAutomationHint({
    required this.driver,
    this.action = IntentAutomationAction.click,
    this.locator = const {},
  }) {
    if (driver.trim().isEmpty) {
      throw ArgumentError.value(driver, 'driver', 'must not be empty');
    }
    final locatorDriven = switch (action) {
      IntentAutomationAction.click ||
      IntentAutomationAction.type ||
      IntentAutomationAction.key ||
      IntentAutomationAction.custom => true,
      IntentAutomationAction.navigate ||
      IntentAutomationAction.evaluate => false,
    };
    if (locatorDriven && locator.isEmpty) {
      throw ArgumentError.value(
        locator,
        'locator',
        'must not be empty for ${action.wire}',
      );
    }
    if (action == IntentAutomationAction.custom &&
        (locator['name'] ?? '').trim().isEmpty) {
      throw ArgumentError.value(
        locator,
        'locator',
        "custom hints must name the catalog action under locator['name']",
      );
    }
  }

  /// Restores a hint from [toJson] output; `null` when absent or malformed.
  ///
  /// Tolerates hints written before `action` existed (absent action means
  /// [IntentAutomationAction.click], the historical default).
  static IntentAutomationHint? fromJson(final Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    final driver = json['driver'];
    if (driver is! String || driver.isEmpty) return null;
    final action = IntentAutomationAction.tryParse(json['action']) ??
        (json['action'] == null ? IntentAutomationAction.click : null);
    if (action == null) return null;
    final rawLocator = json['locator'];
    final coerced = <String, String>{
      if (rawLocator is Map<Object?, Object?>)
        for (final entry in rawLocator.entries)
          if (entry.key is String && entry.value is String)
            entry.key! as String: entry.value! as String,
    };
    if (rawLocator == null && !locatorRequired(action)) return null;
    if (coerced.isEmpty && locatorRequired(action)) return null;
    return IntentAutomationHint(
      driver: driver,
      action: action,
      locator: coerced,
    );
  }

  static bool locatorRequired(final IntentAutomationAction action) =>
      switch (action) {
        IntentAutomationAction.click ||
        IntentAutomationAction.type ||
        IntentAutomationAction.key ||
        IntentAutomationAction.custom => true,
        IntentAutomationAction.navigate ||
        IntentAutomationAction.evaluate => false,
      };

  /// Driver transport family (`toolkit`, `cdp`, `webdriver`, `ax`, …).
  ///
  /// Free-form on purpose: transports are registered elsewhere; the hint
  /// only names the one that fits.
  final String driver;

  /// The driver verb an invocation layer should route to.
  final IntentAutomationAction action;

  /// Locator to resolve against the driver's snapshot (`ref`, `name`,
  /// `role`, `css` — the consuming driver defines the grammar). Empty for
  /// [IntentAutomationAction.navigate]/[IntentAutomationAction.evaluate],
  /// whose operands come from the invocation. [IntentAutomationAction.custom]
  /// hints carry the catalog action name under `name`.
  final Map<String, String> locator;

  /// Serializes the hint (JSON-encodable, payload-free).
  Map<String, Object?> toJson() => {
    'driver': driver,
    'action': action.wire,
    'locator': locator,
  };

  @override
  String toString() => 'IntentAutomationHint($driver, ${action.wire}, '
      '$locator)';
}
