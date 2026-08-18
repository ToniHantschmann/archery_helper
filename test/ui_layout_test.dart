import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/core/theme/timer_theme.dart';
import 'package:archery_helper/models/signal_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/menu_navigation_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout guards for the redesign.
///
/// There is no display on the build machine, so "it looks right" cannot be
/// checked here. What can be checked is that every screen lays out without a
/// RenderFlex overflow at the sizes it actually runs at — the two tunnel
/// monitors and a windowed session on a laptop.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Sizes the app runs at: 1080p and 1440p kiosk monitors, plus a small
  /// window for development.
  const sizes = <String, Size>{
    '1920x1080': Size(1920, 1080),
    '2560x1440': Size(2560, 1440),
    '1280x720': Size(1280, 720),
  };

  Future<void> pumpScreen(
    WidgetTester tester,
    Size size,
    AppScreen screen,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container.read(appStateProvider.notifier).navigateToScreen(screen);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArcheryHelperApp(),
      ),
    );

    // Let the implicit animations (lamp crossfade, gradient, selection) run out
    // without waiting for the idle screen's clock timer, which pumpAndSettle
    // would chase for a full minute.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Leaves the current screen so widgets holding a timer (the idle clock) are
  /// disposed before the test ends.
  Future<void> leaveScreen(WidgetTester tester) async {
    container.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
    await tester.pump();
  }

  group('screens lay out without overflow', () {
    for (final entry in sizes.entries) {
      for (final screen in AppScreen.values) {
        testWidgets('${screen.name} at ${entry.key}', (tester) async {
          await pumpScreen(tester, entry.value, screen);

          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.name} must fit into ${entry.key}',
          );

          await leaveScreen(tester);
        });
      }
    }

    testWidgets('the running timer screen fits while counting down', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1280, 720), AppScreen.timer);

      container.read(timerProvider.notifier).startTimer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);

      container.read(timerProvider.notifier).resetTimer();
      await tester.pump();
    });

    for (final entry in sizes.entries) {
      testWidgets('the traffic light screen fits at ${entry.key}', (
        tester,
      ) async {
        // The signal word takes the whole clock area here, so it is scaled up
        // much further than a countdown ever is.
        container.read(timerProvider.notifier).setMode(TimerMode.trafficLight);
        await pumpScreen(tester, entry.value, AppScreen.timer);

        expect(tester.takeException(), isNull);

        container.read(timerProvider.notifier).advance();
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      });
    }

    for (final entry in sizes.entries) {
      testWidgets('the alternating screen fits mid-round at ${entry.key}', (
        tester,
      ) async {
        // Widest case of this mode: the long phase word ("Vorbereitung A")
        // next to the arrow chip in the status rail.
        container.read(timerProvider.notifier).setMode(TimerMode.alternating);
        await pumpScreen(tester, entry.value, AppScreen.timer);

        container.read(timerProvider.notifier).startTimer();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);

        // And once the duel is running, on the second archer.
        await tester.pump(const Duration(seconds: 30));
        expect(tester.takeException(), isNull);

        container.read(timerProvider.notifier).resetTimer();
        await tester.pump();
      });
    }

    for (final entry in sizes.entries) {
      testWidgets('the competition screen fits mid-round at ${entry.key}', (
        tester,
      ) async {
        // Widest case: the group rail only has content once a round is running,
        // and the status rail carries the end counter next to the discipline.
        await pumpScreen(tester, entry.value, AppScreen.competition);

        container.read(competitionProvider.notifier).start();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);

        // And on the second group of the end, after the changeover.
        container.read(competitionProvider.notifier).skipPhase();
        container.read(competitionProvider.notifier).skipPhase();
        await tester.pump(const Duration(milliseconds: 600));

        expect(container.read(competitionProvider).groupIndex, 1);
        expect(tester.takeException(), isNull);

        container.read(competitionProvider.notifier).reset();
        await tester.pump();
      });
    }
  });

  group('menu keyboard wiring', () {
    testWidgets('arrow keys move the selection and Enter opens the entry', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      expect(container.read(menuNavigationProvider), MenuItem.timer);

      // At 1920px the grid is three wide, so down lands on the second row —
      // the settings tile below the timer tile.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.timerSettings);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(container.read(currentScreenProvider), AppScreen.timerSettings);
    });

    testWidgets('Esc does nothing — the menu is the home screen', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(currentScreenProvider), AppScreen.menu);
    });

    testWidgets('left and right step through a three-column grid', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      expect(
        container.read(menuColumnsProvider),
        3,
        reason: '1920px is wide enough for three tiles in one row',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.competition);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.timer);

      // Right wraps around the flat order, so the last tile is reachable from
      // the first without going through the grid.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.generalSettings);
    });

    testWidgets('down moves a whole row once the grid wraps', (tester) async {
      await pumpScreen(tester, const Size(1280, 720), AppScreen.menu);

      expect(
        container.read(menuColumnsProvider),
        2,
        reason: '1280px is too narrow for three readable tiles',
      );

      // Two columns: the tile below the timer is the third entry, not the
      // second.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.idle);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.timer);
    });

    /// Kein Pfeil darf ins Leere gehen: hoch aus der ersten Zeile landet in der
    /// letzten — in derselben Spalte, so wie links/rechts in der Reihenfolge
    /// herumläuft.
    testWidgets('up from the first row wraps within the column', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.timerSettings);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.timer);
    });
  });

  group('signal semantics', () {
    SignalState stateFor(
      TimerPhase phase, {
      Duration remaining = const Duration(seconds: 60),
    }) {
      return TimerState(
        remainingTime: remaining,
        phase: phase,
        mode: TimerMode.indoor,
        preparationTime: const Duration(seconds: 10),
        mainTime: const Duration(seconds: 120),
      ).signal;
    }

    test('red while nobody may shoot', () {
      expect(TimerTheme.signalFor(stateFor(TimerPhase.idle)), TrafficSignal.red);
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.preparation)),
        TrafficSignal.red,
      );
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.ended)),
        TrafficSignal.red,
        reason: 'a screen with no signal would read as a broken display',
      );
    });

    test('green during the shooting time', () {
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.active)),
        TrafficSignal.green,
      );
    });

    test('amber once the warning threshold is reached', () {
      expect(
        TimerTheme.signalFor(
          stateFor(TimerPhase.active, remaining: const Duration(seconds: 25)),
        ),
        TrafficSignal.amber,
      );
    });

    test('the hand-switched signal is only ever red or green', () {
      SignalState manual(TimerPhase phase) => TimerState(
        remainingTime: Duration.zero,
        phase: phase,
        mode: TimerMode.trafficLight,
        preparationTime: Duration.zero,
        mainTime: Duration.zero,
      ).signal;

      expect(
        TimerTheme.signalFor(manual(TimerPhase.preparation)),
        TrafficSignal.red,
      );
      expect(
        TimerTheme.signalFor(manual(TimerPhase.active)),
        TrafficSignal.green,
        reason: 'zero remaining time must not read as a warning period',
      );
    });
  });
}
