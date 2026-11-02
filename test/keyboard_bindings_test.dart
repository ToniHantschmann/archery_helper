import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/core/l10n/keyboard_texts.dart';
import 'package:archery_helper/models/keyboard_config.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:archery_helper/providers/keyboard_navigation_provider.dart';
import 'package:archery_helper/providers/settings_navigation_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:archery_helper/repositories/keyboard_config_repository.dart';
import 'package:archery_helper/screens/keyboard_settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zusatztasten: die Regeln im Modell und der Weg durch den Screen, so wie
/// ihn jemand mit dem Ziffernblock in der Hand geht.
void main() {
  group('extra keys in the model', () {
    const empty = KeyboardConfig();

    test('a free key is added after the default keys', () {
      final (config, result) = empty.withExtraKey(
        LogicalKeyboardKey.numpad0,
        AppAction.next,
      );

      expect(result.outcome, KeyAssignmentOutcome.added);
      expect(config.getAction(LogicalKeyboardKey.numpad0), AppAction.next);
      expect(
        config.getKeysForAction(AppAction.next),
        [LogicalKeyboardKey.space, LogicalKeyboardKey.numpad0],
        reason: 'the hint rails show the first key, the familiar one',
      );
    });

    test('a default key is fixed and stays where it is', () {
      final (config, result) = empty.withExtraKey(
        LogicalKeyboardKey.keyR,
        AppAction.next,
      );

      expect(result.outcome, KeyAssignmentOutcome.fixed);
      expect(result.other, AppAction.resetTimer);
      expect(config, same(empty));
    });

    test('a default key of the same action changes nothing', () {
      final (_, result) = empty.withExtraKey(
        LogicalKeyboardKey.space,
        AppAction.next,
      );

      expect(result.outcome, KeyAssignmentOutcome.unchanged);
    });

    test('an extra key of another action is moved over', () {
      final (onReset, _) = empty.withExtraKey(
        LogicalKeyboardKey.numpad5,
        AppAction.resetTimer,
      );
      final (config, result) = onReset.withExtraKey(
        LogicalKeyboardKey.numpad5,
        AppAction.toggleTimer,
      );

      expect(result.outcome, KeyAssignmentOutcome.moved);
      expect(result.other, AppAction.resetTimer);
      expect(config.extraKeysFor(AppAction.resetTimer), isEmpty);
      expect(
        config.getAction(LogicalKeyboardKey.numpad5),
        AppAction.toggleTimer,
      );
    });

    test('removing takes the last added extra key and never a default', () {
      final (one, _) = empty.withExtraKey(
        LogicalKeyboardKey.numpad1,
        AppAction.back,
      );
      final (two, _) = one.withExtraKey(
        LogicalKeyboardKey.numpad2,
        AppAction.back,
      );

      final removed = two.withoutLastExtraKey(AppAction.back);
      expect(removed.extraKeysFor(AppAction.back), [
        LogicalKeyboardKey.numpad1,
      ]);

      final none = removed
          .withoutLastExtraKey(AppAction.back)
          .withoutLastExtraKey(AppAction.back);
      expect(none.getKeysForAction(AppAction.back), [
        LogicalKeyboardKey.escape,
      ]);
    });

    test('numpad keys get short cap labels', () {
      expect(KeyboardConfig.getKeyName(LogicalKeyboardKey.numpad7), 'Num 7');
      expect(KeyboardConfig.getKeyName(LogicalKeyboardKey.numpadAdd), 'Num +');
      expect(
        KeyboardConfig.getKeyName(LogicalKeyboardKey.numpadEnter),
        'Num ↵',
      );
    });
  });

  /// Die Auswahl läuft durch [keyboardRows], der Screen zeichnet die
  /// Abschnitte — beide müssen dieselbe Reihenfolge haben.
  test('the screen sections list every action once, in row order', () {
    final shown = [
      for (final (_, actions) in keyboardSections(
        const KeyboardTexts(AppLanguage.german),
      ))
        ...actions,
    ];

    expect(shown, AppAction.values);
    expect(keyboardRows, [...AppAction.values, null]);
  });

  group('the key binding screen', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    Future<void> pumpApp(WidgetTester tester, AppScreen startAt) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container.read(appStateProvider.notifier).navigateToScreen(startAt);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ArcheryHelperApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    AppScreen currentScreen() => container.read(currentScreenProvider);
    KeyboardConfig config() => container.read(keyboardConfigProvider);
    KeyboardNavState nav() => container.read(keyboardNavigationProvider);
    void selectRow(AppAction? row) =>
        container.read(keyboardNavigationProvider.notifier).select(row);

    testWidgets('a numpad key recorded here starts the Ampel', (tester) async {
      await pumpApp(tester, AppScreen.generalSettings);

      container
          .read(settingsNavigationProvider.notifier)
          .select(SettingsItem.keyBindings);
      await press(tester, LogicalKeyboardKey.enter);
      expect(currentScreen(), AppScreen.keyboardSettings);

      selectRow(AppAction.next);
      await press(tester, LogicalKeyboardKey.enter);
      expect(nav().capturing, isTrue);

      await press(tester, LogicalKeyboardKey.numpad0);
      expect(nav().capturing, isFalse);
      expect(config().getAction(LogicalKeyboardKey.numpad0), AppAction.next);

      await press(tester, LogicalKeyboardKey.escape);
      expect(currentScreen(), AppScreen.generalSettings);

      container
          .read(appStateProvider.notifier)
          .navigateToScreen(AppScreen.timer);
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.numpad0);
      expect(container.read(timerProvider).phase, TimerPhase.preparation);

      container.read(timerProvider.notifier).resetTimer();
      await tester.pumpAndSettle();

      // Und nach einem Neustart ist sie noch da.
      final reloaded = await KeyboardConfigRepository().loadConfig();
      expect(reloaded.getAction(LogicalKeyboardKey.numpad0), AppAction.next);
    });

    testWidgets('a held Enter does not record itself', (tester) async {
      await pumpApp(tester, AppScreen.keyboardSettings);
      selectRow(AppAction.confirm);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(nav().capturing, isTrue);
      expect(nav().notice, isNull);

      // Shift allein ist keine Taste, die jemand meint.
      await press(tester, LogicalKeyboardKey.shiftLeft);
      expect(nav().capturing, isTrue);

      await press(tester, LogicalKeyboardKey.numpadEnter);
      expect(
        config().getAction(LogicalKeyboardKey.numpadEnter),
        AppAction.confirm,
      );
    });

    testWidgets('Esc cancels a capture without leaving or binding', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.keyboardSettings);

      await press(tester, LogicalKeyboardKey.enter);
      expect(nav().capturing, isTrue);

      await press(tester, LogicalKeyboardKey.escape);
      expect(nav().capturing, isFalse);
      expect(currentScreen(), AppScreen.keyboardSettings);
      expect(config().extraBindings, isEmpty);
    });

    testWidgets('a default key is refused and the row says why', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.keyboardSettings);
      selectRow(AppAction.toggleTimer);
      await tester.pump();

      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.keyR);

      expect(nav().notice?.outcome, KeyAssignmentOutcome.fixed);
      expect(config().getAction(LogicalKeyboardKey.keyR), AppAction.resetTimer);
      expect(find.textContaining('fest mit'), findsOneWidget);
      expect(container.read(timerProvider).phase, TimerPhase.idle);
    });

    testWidgets('Delete removes the extra key again', (tester) async {
      await pumpApp(tester, AppScreen.keyboardSettings);
      container
          .read(keyboardConfigProvider.notifier)
          .addExtraKey(LogicalKeyboardKey.numpad9, AppAction.toggleTimer);
      await tester.pump();

      await press(tester, LogicalKeyboardKey.delete);

      expect(config().extraKeysFor(AppAction.toggleTimer), isEmpty);
    });

    testWidgets('the reset row clears every extra key in two steps', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.keyboardSettings);
      container.read(keyboardConfigProvider.notifier)
        ..addExtraKey(LogicalKeyboardKey.numpad1, AppAction.back)
        ..addExtraKey(LogicalKeyboardKey.numpad2, AppAction.navigateDown);

      // Hoch von der ersten Zeile läuft um auf die Reset-Zeile.
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(nav().selected, isNull);

      await press(tester, LogicalKeyboardKey.enter);
      expect(nav().resetArmed, isTrue);
      expect(config().extraBindings, hasLength(2));

      // Das erste Esc entschärft nur.
      await press(tester, LogicalKeyboardKey.escape);
      expect(nav().resetArmed, isFalse);
      expect(currentScreen(), AppScreen.keyboardSettings);

      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.enter);
      expect(config().extraBindings, isEmpty);
    });

    /// Ob eine Taste beim Halten wiederholt, hängt an ihrer Aktion, nicht an
    /// der Taste — eine Zusatztaste fürs Runter tut also dasselbe wie ↓.
    testWidgets('a held extra navigation key repeats', (tester) async {
      await pumpApp(tester, AppScreen.keyboardSettings);
      container
          .read(keyboardConfigProvider.notifier)
          .addExtraKey(LogicalKeyboardKey.numpad2, AppAction.navigateDown);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.numpad2);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.numpad2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.numpad2);
      await tester.pumpAndSettle();

      expect(nav().selected, AppAction.skipTimer);
    });
  });
}
