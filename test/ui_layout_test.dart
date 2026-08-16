import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/core/theme/timer_theme.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
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
    container.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
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
  });

  group('menu keyboard wiring', () {
    testWidgets('arrow keys move the selection and Enter opens the entry', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      expect(container.read(menuNavigationProvider), MenuItem.timer);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider), MenuItem.settings);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(container.read(currentScreenProvider), AppScreen.settings);
    });

    testWidgets('Esc returns to the timer', (tester) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(currentScreenProvider), AppScreen.timer);
    });
  });

  group('traffic light semantics', () {
    TimerState stateFor(
      TimerPhase phase, {
      Duration remaining = const Duration(seconds: 60),
    }) {
      return TimerState(
        remainingTime: remaining,
        phase: phase,
        mode: TimerMode.indoor,
        preparationTime: const Duration(seconds: 10),
        mainTime: const Duration(seconds: 120),
      );
    }

    test('red while nobody may shoot', () {
      expect(TimerTheme.lampFor(stateFor(TimerPhase.idle)), TrafficLamp.red);
      expect(
        TimerTheme.lampFor(stateFor(TimerPhase.preparation)),
        TrafficLamp.red,
      );
      expect(
        TimerTheme.lampFor(stateFor(TimerPhase.ended)),
        TrafficLamp.red,
        reason: 'a dark traffic light would read as a broken display',
      );
    });

    test('green during the shooting time', () {
      expect(
        TimerTheme.lampFor(stateFor(TimerPhase.active)),
        TrafficLamp.green,
      );
    });

    test('amber once the warning threshold is reached', () {
      expect(
        TimerTheme.lampFor(
          stateFor(TimerPhase.active, remaining: const Duration(seconds: 25)),
        ),
        TrafficLamp.amber,
      );
    });
  });

  group('phase progress', () {
    TimerState running(Duration remaining) {
      return TimerState(
        remainingTime: remaining,
        phase: TimerPhase.preparation,
        mode: TimerMode.indoor,
        preparationTime: const Duration(seconds: 10),
        mainTime: const Duration(seconds: 120),
      );
    }

    test('runs from full to empty over the phase', () {
      expect(TimerTheme.phaseProgress(running(const Duration(seconds: 10))), 1);
      expect(
        TimerTheme.phaseProgress(running(const Duration(seconds: 5))),
        0.5,
      );
    });

    test('is quantised to whole seconds', () {
      // Everything inside the same second must give the same value, otherwise
      // the progress rail would repaint ten times a second.
      expect(
        TimerTheme.phaseProgress(running(const Duration(milliseconds: 4100))),
        TimerTheme.phaseProgress(running(const Duration(milliseconds: 4900))),
      );
    });

    test('is full while idle and empty once ended', () {
      const base = TimerState(
        remainingTime: Duration(seconds: 120),
        phase: TimerPhase.idle,
        mode: TimerMode.indoor,
        preparationTime: Duration(seconds: 10),
        mainTime: Duration(seconds: 120),
      );

      expect(TimerTheme.phaseProgress(base), 1.0);
      expect(
        TimerTheme.phaseProgress(base.copyWith(phase: TimerPhase.ended)),
        0.0,
      );
    });

    test('survives a mode without durations', () {
      const trafficLightOnly = TimerState(
        remainingTime: Duration.zero,
        phase: TimerPhase.active,
        mode: TimerMode.trafficLight,
        preparationTime: Duration.zero,
        mainTime: Duration.zero,
      );

      expect(TimerTheme.phaseProgress(trafficLightOnly), 0.0);
    });
  });
}
