import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';

void main() {
  group('IntentAutomationHint', () {
    test('rejects an empty driver or locator', () {
      expect(
        () => IntentAutomationHint(driver: ' ', locator: const {'name': 'Buy'}),
        throwsArgumentError,
      );
      expect(() => IntentAutomationHint(driver: 'toolkit'), throwsArgumentError);
    });

    test('round-trips through JSON including the action', () {
      final hint = IntentAutomationHint(driver: 'toolkit', locator: const {
        'name': 'Buy',
        'role': 'button',
      });
      final restored = IntentAutomationHint.fromJson(hint.toJson());
      expect(restored, isNotNull);
      expect(restored!.driver, 'toolkit');
      expect(restored.action, IntentAutomationAction.click);
      expect(restored.locator, {'name': 'Buy', 'role': 'button'});

      final typing = IntentAutomationHint(
        driver: 'toolkit',
        action: IntentAutomationAction.type,
        locator: const {'css': 's_12'},
      );
      final restoredTyping = IntentAutomationHint.fromJson(typing.toJson());
      expect(restoredTyping!.action, IntentAutomationAction.type);
    });

    test('fromJson treats a pre-action hint as a click', () {
      final restored = IntentAutomationHint.fromJson(const {
        'driver': 'cdp',
        'locator': {'css': '#buy'},
      });
      expect(restored!.action, IntentAutomationAction.click);
      expect(
        IntentAutomationHint.fromJson(const {
          'driver': 'cdp',
          'action': 'explode',
          'locator': {'css': '#buy'},
        }),
        isNull,
      );
    });

    test('fromJson is null-safe for absent or malformed input', () {
      expect(IntentAutomationHint.fromJson(null), isNull);
      expect(IntentAutomationHint.fromJson('toolkit'), isNull);
      expect(IntentAutomationHint.fromJson({'driver': 'toolkit'}), isNull);
      expect(
        IntentAutomationHint.fromJson(<Object?, Object?>{
          'driver': 'toolkit',
          'locator': <Object?, Object?>{'name': 7},
        }),
        isNull,
      );
    });
  });

  group('IntentAutomationAction', () {
    test('parses wire forms and rejects unknown names', () {
      expect(IntentAutomationAction.tryParse('type'),
          IntentAutomationAction.type);
      expect(IntentAutomationAction.tryParse('evaluate'),
          IntentAutomationAction.evaluate);
      expect(IntentAutomationAction.tryParse('custom'),
          IntentAutomationAction.custom);
      expect(IntentAutomationAction.tryParse('detonate'), isNull);
      expect(IntentAutomationAction.tryParse(null), isNull);
    });

    test('custom hints require the catalog name under locator.name', () {
      expect(
        () => IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.custom,
        ),
        throwsArgumentError,
      );
      expect(
        () => IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.custom,
          locator: const {'role': 'button'},
        ),
        throwsArgumentError,
      );
    });

    test('custom hints round-trip through JSON', () {
      final hint = IntentAutomationHint(
        driver: 'toolkit',
        action: IntentAutomationAction.custom,
        locator: const {'name': 'app.checkout_flow'},
      );
      final restored = IntentAutomationHint.fromJson(hint.toJson());
      expect(restored, isNotNull);
      expect(restored!.action, IntentAutomationAction.custom);
      expect(restored.locator['name'], 'app.checkout_flow');
    });

    test('navigate/evaluate carry no locator; click/type/key need one', () {
      expect(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.navigate,
        ),
        isNotNull,
      );
      expect(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.evaluate,
        ),
        isNotNull,
      );
      for (final action in [
        IntentAutomationAction.click,
        IntentAutomationAction.type,
        IntentAutomationAction.key,
      ]) {
        expect(
          () => IntentAutomationHint(driver: 'toolkit', action: action),
          throwsArgumentError,
          reason: '${action.wire} is locator-driven',
        );
      }
    });
  });

  group('AgentIntentDescriptor.automation', () {
    AgentIntentDescriptor descriptorWith(final IntentAutomationHint? hint) =>
        AgentIntentDescriptor(
          namespace: 'app',
          name: 'buy_item',
          description: 'Buys an item',
          kind: AgentIntentKind.tool,
          inputSchema: const {'type': 'object'},
          automation: hint,
        );

    test('defaults to null (no hint) — additive for existing entries', () {
      expect(descriptorWith(null).automation, isNull);
    });

    test('carries the hint through registration', () {
      final hint = IntentAutomationHint(driver: 'toolkit', locator: const {
        'name': 'Buy',
      });
      final entry = AgentCallEntry.tool(
        namespace: 'app',
        name: 'buy_item',
        description: 'Buys an item',
        inputSchema: const {'type': 'object'},
        handler: (_) => AgentResult.success(),
        automation: hint,
      );
      expect(entry.toRegistration().descriptor.automation, same(hint));
    });
  });
}
