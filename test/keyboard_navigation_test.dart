import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/settings_navigation_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for the app-wide keyboard path:
/// KeyboardScope → AppActionsNotifier → ScreenActionHandler → providers.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Pumps the real app so the test exercises the actual widget tree,
  /// including KeyboardScope in app.dart.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1920, 1080),
  }) async {
    // The default 800x600 test surface is far smaller than the tunnel monitors
    // and makes the timer button row overflow, which would fail every test.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArcheryHelperApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
  }

  /// Settings writes are debounced, so a test that changed a setting leaves a
  /// pending timer behind. Let it run before the test ends.
  Future<void> flushPendingSaves(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  /// A running countdown keeps its periodic Timer alive, which the test
  /// framework flags after teardown. Stop it explicitly.
  Future<void> stopTimer(WidgetTester tester) async {
    container.read(timerProvider.notifier).resetTimer();
    await tester.pumpAndSettle();
  }

  AppScreen currentScreen() => container.read(currentScreenProvider);
  SettingsItem selectedItem() => container.read(selectedSettingsItemProvider);
  Settings settings() => container.read(settingsProvider);
  TimerState timer() => container.read(timerProvider);
  bool resetArmed() => container.read(isResetArmedProvider);

  void select(SettingsItem item) =>
      container.read(settingsNavigationProvider.notifier).select(item);

  group('screen navigation', () {
    testWidgets('S opens the settings screen and Esc leaves it again', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(currentScreen(), AppScreen.timer);

      await openSettings(tester);
      expect(currentScreen(), AppScreen.settings);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        currentScreen(),
        AppScreen.timer,
        reason: 'a kiosk without a mouse must be able to leave every screen',
      );
    });

    testWidgets('mode cycling still works on the timer screen', (tester) async {
      await pumpApp(tester);
      expect(currentScreen(), AppScreen.timer);

      final before = timer().mode;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();

      expect(timer().mode, isNot(before));
      expect(TimerMode.values.contains(timer().mode), isTrue);
    });

    testWidgets('nothing below the scope can take the keyboard focus', (
      tester,
    ) async {
      await pumpApp(tester);

      final focusManager = tester.binding.focusManager;
      expect(focusManager.primaryFocus?.debugLabel, 'KeyboardScope');

      // Traversal must not hand focus to one of the on-screen buttons —
      // a focused button would swallow Space and Enter.
      focusManager.primaryFocus!.nextFocus();
      await tester.pumpAndSettle();
      expect(focusManager.primaryFocus?.debugLabel, 'KeyboardScope');

      // ...and keys still arrive at the scope.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(timer().isRunning, isTrue);

      await stopTimer(tester);
    });
  });

  group('settings selection', () {
    testWidgets('arrow down and up move the selection', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(selectedItem(), SettingsItem.language);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.soundEnabled);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.language);
    });

    testWidgets('volume is skipped while sound is off', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      container.read(settingsProvider.notifier).toggleSound();
      expect(settings().soundEnabled, isFalse);

      select(SettingsItem.soundEnabled);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        selectedItem(),
        SettingsItem.defaultMode,
        reason: 'the disabled volume slider would be a dead stop',
      );

      await flushPendingSaves(tester);
    });

    /// The selected row is scrolled into view, but only when it is not already
    /// visible. Scrolling on every step used to restart a centring animation
    /// faster than it could finish, so the list crawled behind a held arrow
    /// key. A small window is used on purpose — on the tunnel monitors the list
    /// does not scroll at all, so the guard would never be exercised.
    testWidgets('moving between visible rows does not scroll the list', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1280, 720));
      await openSettings(tester);

      final list = find.byType(Scrollable).last;
      final position = tester.state<ScrollableState>(list).position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: 'the guard is only meaningful while the list can scroll',
      );

      final offsetAtTop = position.pixels;

      // The first rows share the viewport with the selection, so stepping
      // between them must leave the scroll offset alone.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.soundEnabled);
      expect(
        position.pixels,
        offsetAtTop,
        reason: 'a row that is already visible must not move the viewport',
      );

      // Stepping on towards the end of the list must still bring the viewport
      // along. Done key by key on purpose: the list builds its children lazily,
      // so a row far outside the viewport has no context to scroll to yet —
      // walking there is what the keyboard actually does.
      while (selectedItem() != SettingsItem.resetToDefaults) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      expect(
        position.pixels,
        greaterThan(offsetAtTop),
        reason: 'a row outside the viewport must still be scrolled into view',
      );
    });
  });

  group('settings value editing', () {
    testWidgets('arrow keys adjust the selected duration', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.customMainTime);
      final before = settings().customMainTime;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(settings().customMainTime, before + const Duration(seconds: 1));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(settings().customMainTime, before - const Duration(seconds: 1));

      await flushPendingSaves(tester);
    });

    testWidgets('space toggles the selected switch instead of the timer', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.autoStart);
      expect(settings().autoStart, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(settings().autoStart, isTrue);
      expect(
        timer().isRunning,
        isFalse,
        reason: 'space must not start the timer while the settings are open',
      );

      await flushPendingSaves(tester);
    });
  });

  group('key repeat', () {
    testWidgets('holding an arrow key keeps stepping the value', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.customMainTime);
      final before = settings().customMainTime;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        settings().customMainTime,
        before + const Duration(seconds: 3),
        reason: 'one step for the key down plus one per repeat',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('holding a non-navigation key does not repeat', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.autoStart);
      expect(settings().autoStart, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        settings().autoStart,
        isTrue,
        reason: 'repeats must be ignored, otherwise the switch flips back',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('holding space on the timer screen starts it only once', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      final phaseAfterStart = timer().phase;

      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        timer().phase,
        phaseAfterStart,
        reason: 'repeats would otherwise skip through the timer phases',
      );

      await stopTimer(tester);
    });
  });

  group('reset confirmation', () {
    testWidgets('reset needs two confirmations', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      container.read(settingsProvider.notifier).toggleAutoStart();
      expect(settings().autoStart, isTrue);

      select(SettingsItem.resetToDefaults);

      // First confirm only arms the row.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);
      expect(settings().autoStart, isTrue);

      // Second confirm performs the reset.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isFalse);
      expect(settings().autoStart, isFalse);

      await flushPendingSaves(tester);
    });

    testWidgets('Esc cancels the pending reset without leaving the screen', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      container.read(settingsProvider.notifier).toggleAutoStart();
      select(SettingsItem.resetToDefaults);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(resetArmed(), isFalse);
      expect(settings().autoStart, isTrue, reason: 'nothing was reset');
      expect(
        currentScreen(),
        AppScreen.settings,
        reason: 'the first Esc is consumed by the confirmation',
      );

      // Only the next Esc leaves.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(currentScreen(), AppScreen.timer);

      await flushPendingSaves(tester);
    });

    testWidgets('moving the selection away cancels the pending reset', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.resetToDefaults);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(resetArmed(), isFalse);
      expect(selectedItem(), isNot(SettingsItem.resetToDefaults));
    });
  });
}
