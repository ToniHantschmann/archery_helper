import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the countdown itself: TimerNotifier's phase machine, its timers
/// and the way it picks up custom durations from the settings.
///
/// These use `testWidgets` without pumping a widget, purely to get the fake
/// clock — `tester.pump(duration)` advances it and fires the notifier's
/// timers, so a full 2 minute countdown runs instantly.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  TimerNotifier notifier() => container.read(timerProvider.notifier);
  TimerState timer() => container.read(timerProvider);

  /// Stops any running countdown so no periodic Timer survives the test.
  void stop() => notifier().resetTimer();

  group('initial state', () {
    test('starts idle with preparation and main time added up', () {
      // Default mode is indoor: 10s preparation + 120s main.
      expect(timer().phase, TimerPhase.idle);
      expect(timer().isRunning, isFalse);
      expect(timer().preparationTime, const Duration(seconds: 10));
      expect(timer().mainTime, const Duration(seconds: 120));
      expect(timer().remainingTime, const Duration(seconds: 130));
    });

    test('follows the default mode from the settings', () {
      // Settings are loaded before the timer is first read (see main.dart),
      // so the initial mode comes from them.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh.read(settingsProvider.notifier).setDefaultMode(TimerMode.outdoor);

      expect(fresh.read(timerProvider).mode, TimerMode.outdoor);
      expect(fresh.read(timerProvider).mainTime, const Duration(seconds: 240));
    });
  });

  group('countdown', () {
    testWidgets('counts down in 100ms steps', (tester) async {
      notifier().startTimer();

      expect(timer().phase, TimerPhase.preparation);
      expect(timer().remainingTime, const Duration(seconds: 10));

      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().remainingTime, const Duration(milliseconds: 9900));

      await tester.pump(const Duration(milliseconds: 1400));
      expect(timer().remainingTime, const Duration(milliseconds: 8500));

      stop();
    });

    testWidgets('runs preparation → active → ended in the configured time', (
      tester,
    ) async {
      notifier().startTimer();
      expect(timer().phase, TimerPhase.preparation);

      // A phase lasts exactly as long as it is configured for — no padding
      // for the display, that is formatTime's job (see timer_texts_test.dart).
      await tester.pump(const Duration(milliseconds: 9900));
      expect(timer().phase, TimerPhase.preparation);
      expect(timer().remainingTime, const Duration(milliseconds: 100));

      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().phase, TimerPhase.active);
      expect(timer().remainingTime, const Duration(seconds: 120));
      expect(timer().isRunning, isTrue);

      await tester.pump(const Duration(seconds: 120));
      expect(timer().phase, TimerPhase.ended);
      expect(timer().remainingTime, Duration.zero);
      expect(timer().isRunning, isFalse);
      expect(timer().isFinished, isTrue);
    });
  });

  group('pause and resume', () {
    testWidgets('pause freezes the remaining time', (tester) async {
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));

      final frozen = timer().remainingTime;
      notifier().pauseTimer();

      await tester.pump(const Duration(seconds: 5));
      expect(timer().remainingTime, frozen);
      expect(timer().isPaused, isTrue);
      expect(timer().isRunning, isFalse);

      stop();
    });

    testWidgets('pause freezes on the clock, not on the last tick', (
      tester,
    ) async {
      notifier().startTimer();

      // Two ticks fired, then another 70ms of real time passed without a
      // callback. The remaining time is derived from the clock, so those 70ms
      // are gone — counting ticks would still claim 9.8s are left.
      await tester.pump(const Duration(milliseconds: 270));
      notifier().pauseTimer();

      expect(timer().remainingTime, const Duration(milliseconds: 9700));

      stop();
    });

    testWidgets('resume continues from where it was paused', (tester) async {
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));
      final frozen = timer().remainingTime;

      notifier().pauseTimer();
      await tester.pump(const Duration(seconds: 5));
      notifier().startTimer();

      expect(timer().isRunning, isTrue);
      expect(timer().isPaused, isFalse);
      expect(timer().remainingTime, frozen);

      await tester.pump(const Duration(seconds: 1));
      expect(timer().remainingTime, frozen - const Duration(seconds: 1));

      stop();
    });
  });

  group('skip, advance and toggle', () {
    testWidgets('skip jumps to the next phase', (tester) async {
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 2));

      notifier().skipTimerPhase();
      expect(timer().phase, TimerPhase.active);
      expect(timer().remainingTime, const Duration(seconds: 120));

      notifier().skipTimerPhase();
      expect(timer().phase, TimerPhase.ended);
      expect(timer().isRunning, isFalse);

      // The skipped phase must not keep ticking in the background.
      await tester.pump(const Duration(seconds: 5));
      expect(timer().phase, TimerPhase.ended);
      expect(timer().remainingTime, Duration.zero);
    });

    testWidgets('skip does nothing while the timer is idle or paused', (
      tester,
    ) async {
      notifier().skipTimerPhase();
      expect(timer().phase, TimerPhase.idle);

      notifier().startTimer();
      await tester.pump(const Duration(seconds: 2));
      notifier().pauseTimer();

      notifier().skipTimerPhase();
      expect(timer().phase, TimerPhase.preparation);

      stop();
    });

    testWidgets('advance skips a running phase, toggle pauses it', (
      tester,
    ) async {
      // Both are bound to keys (Space / P) and must stay distinguishable.
      notifier().advance();
      expect(timer().phase, TimerPhase.preparation, reason: 'advance starts');

      await tester.pump(const Duration(seconds: 2));
      notifier().advance();
      expect(timer().phase, TimerPhase.active, reason: 'advance skips');

      notifier().toggle();
      expect(timer().phase, TimerPhase.active, reason: 'toggle never skips');
      expect(timer().isPaused, isTrue);

      notifier().toggle();
      expect(timer().isRunning, isTrue);

      stop();
    });

    testWidgets('advance resets once the timer has ended', (tester) async {
      notifier().startTimer();
      notifier().skipTimerPhase();
      notifier().skipTimerPhase();
      expect(timer().phase, TimerPhase.ended);

      notifier().advance();
      expect(timer().phase, TimerPhase.idle);
      expect(timer().remainingTime, const Duration(seconds: 130));

      // toggle() on the other hand ignores a finished timer completely, so
      // the play/pause key cannot restart a round on its own.
      notifier().startTimer();
      notifier().skipTimerPhase();
      notifier().skipTimerPhase();
      notifier().toggle();
      expect(timer().phase, TimerPhase.ended);

      stop();
    });
  });

  group('cancelling a running countdown', () {
    testWidgets('reset stops the timer and returns to idle', (tester) async {
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));

      notifier().resetTimer();
      expect(timer().phase, TimerPhase.idle);
      expect(timer().remainingTime, const Duration(seconds: 130));

      await tester.pump(const Duration(seconds: 5));
      expect(timer().remainingTime, const Duration(seconds: 130));
    });

    testWidgets('changing the mode stops the timer', (tester) async {
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));

      notifier().setMode(TimerMode.outdoor);
      expect(timer().mode, TimerMode.outdoor);
      expect(timer().phase, TimerPhase.idle);
      expect(timer().remainingTime, const Duration(seconds: 250));

      await tester.pump(const Duration(seconds: 5));
      expect(timer().remainingTime, const Duration(seconds: 250));
    });
  });

  group('custom mode', () {
    testWidgets('takes its durations from the settings', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCustomPrepTime(const Duration(seconds: 5));
      container
          .read(settingsProvider.notifier)
          .setCustomMainTime(const Duration(seconds: 30));

      notifier().setMode(TimerMode.custom);
      expect(timer().preparationTime, const Duration(seconds: 5));
      expect(timer().mainTime, const Duration(seconds: 30));
      expect(timer().remainingTime, const Duration(seconds: 35));

      notifier().startTimer();
      await tester.pump(const Duration(seconds: 5));
      expect(timer().phase, TimerPhase.active);
      expect(timer().remainingTime, const Duration(seconds: 30));

      stop();
      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('picks up custom times changed while it is active', (
      tester,
    ) async {
      notifier().setMode(TimerMode.custom);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));

      container
          .read(settingsProvider.notifier)
          .setCustomMainTime(const Duration(seconds: 60));

      // The running countdown is dropped in favour of the new durations.
      expect(timer().mainTime, const Duration(seconds: 60));
      expect(timer().phase, TimerPhase.idle);

      await tester.pump(const Duration(seconds: 5));
      expect(timer().remainingTime, const Duration(seconds: 70));

      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('other modes ignore the custom times', (tester) async {
      notifier().setMode(TimerMode.indoor);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 3));
      final running = timer().remainingTime;

      container
          .read(settingsProvider.notifier)
          .setCustomMainTime(const Duration(seconds: 60));

      expect(timer().phase, TimerPhase.preparation);
      expect(timer().remainingTime, running);
      expect(timer().mainTime, const Duration(seconds: 120));

      stop();
      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });
  });
}
