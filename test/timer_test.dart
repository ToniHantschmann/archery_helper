import 'package:archery_helper/core/l10n/timer_texts.dart';
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

  /// What the tunnel actually shows. Formatted straight from the notifier
  /// rather than through `formattedTimeProvider`: reading a derived provider
  /// after a state change leaves one of Riverpod's own scheduling timers
  /// pending, which `testWidgets` then reports as a leak.
  String display() => TimerTexts.formatTime(timer().remainingTime);

  /// Stops any running countdown so no timer survives the test.
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
    testWidgets('updates once per displayed second, not on a polling grid', (
      tester,
    ) async {
      notifier().startTimer();

      expect(timer().phase, TimerPhase.preparation);
      expect(timer().remainingTime, const Duration(seconds: 10));

      // Nothing happens in between: the update is scheduled onto the moment
      // the shown number changes, so a tenth of a second later the state is
      // still untouched.
      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().remainingTime, const Duration(seconds: 10));

      await tester.pump(const Duration(milliseconds: 900));
      expect(timer().remainingTime, const Duration(seconds: 9));

      // 2.5s in: the update at 2s has run, the one at 3s has not. The state
      // holds whole seconds because nothing polls in between.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timer().remainingTime, const Duration(seconds: 8));

      stop();
    });

    testWidgets('the displayed second never flips early', (tester) async {
      // This is the regression the whole scheduling change is about: polling
      // on a 100ms grid and rounding onto it let a late callback drop a second
      // up to 100ms too soon, so a second could be on screen for 0.9s.
      notifier().startTimer();
      expect(display(), '0:10');

      await tester.pump(const Duration(milliseconds: 999));
      expect(display(), '0:10', reason: 'still within the first second');

      await tester.pump(const Duration(milliseconds: 1));
      expect(display(), '0:09');

      stop();
    });

    testWidgets('every displayed second lasts exactly one second', (
      tester,
    ) async {
      // Walking the whole preparation phase to the millisecond around each
      // boundary: the old 100ms polling let a late callback drop the value up
      // to a step early, so seconds were on screen for 0.9s to 1.1s.
      notifier().startTimer();

      for (var elapsed = 1; elapsed <= 10; elapsed++) {
        await tester.pump(const Duration(milliseconds: 999));
        expect(
          display(),
          TimerTexts.formatTime(Duration(seconds: 11 - elapsed)),
          reason: 'second $elapsed must still be shown 1ms before its end',
        );

        await tester.pump(const Duration(milliseconds: 1));
        if (elapsed < 10) {
          expect(
            timer().remainingTime,
            Duration(seconds: 10 - elapsed),
            reason: 'and must be replaced exactly on the second',
          );
        }
      }

      // The tenth boundary is the end of the phase, not just a display step.
      expect(timer().phase, TimerPhase.active);

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
      expect(timer().remainingTime, const Duration(seconds: 1));

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

  group('tenths display', () {
    testWidgets('switches the countdown to a 100ms grid', (tester) async {
      container.read(settingsProvider.notifier).toggleShowMilliseconds();

      notifier().startTimer();
      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().remainingTime, const Duration(milliseconds: 9900));

      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().remainingTime, const Duration(milliseconds: 9800));

      stop();
      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('re-arms on the new grid when switched mid-phase', (
      tester,
    ) async {
      notifier().startTimer();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(timer().remainingTime, const Duration(seconds: 9));

      // Switching the setting must not disturb the running countdown, only
      // how often it reports — the remaining time is re-read from the clock.
      container.read(settingsProvider.notifier).toggleShowMilliseconds();
      expect(timer().remainingTime, const Duration(milliseconds: 8500));

      await tester.pump(const Duration(milliseconds: 100));
      expect(timer().remainingTime, const Duration(milliseconds: 8400));

      stop();
      await tester.pump(const Duration(milliseconds: 400)); // debounced save
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

    testWidgets('pause freezes on the clock, not on the last update', (
      tester,
    ) async {
      notifier().startTimer();

      // No update has run yet — the next one is due at the full second. The
      // remaining time is nevertheless derived from the clock, so pausing
      // hands back exactly the 270ms that passed and not a rounded value.
      await tester.pump(const Duration(milliseconds: 270));
      notifier().pauseTimer();

      expect(timer().remainingTime, const Duration(milliseconds: 9730));

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

  group('alternating mode', () {
    /// One passage of the duel: the 20s an archer has for a single arrow.
    const passage = Duration(seconds: 20);

    test('starts on archer A with the first arrow', () {
      notifier().setMode(TimerMode.alternating);

      expect(timer().phase, TimerPhase.idle);
      expect(timer().preparationTime, const Duration(seconds: 10));
      expect(timer().mainTime, passage);
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 1);
      expect(timer().arrowsPerArcher, 3);

      // 30s would cover the whole 20s passage — the shot clock would never be
      // green.
      expect(timer().warningThreshold, const Duration(seconds: 5));
    });

    testWidgets('hands over to B after the 20s, without a new preparation', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();

      expect(timer().phase, TimerPhase.preparation);
      expect(timer().currentArcher, Archer.a);

      await tester.pump(const Duration(seconds: 10));
      expect(timer().phase, TimerPhase.active);
      expect(timer().currentArcher, Archer.a);
      expect(timer().remainingTime, passage);

      // Straight into B's passage: no red in between, no second preparation.
      await tester.pump(passage);
      expect(timer().phase, TimerPhase.active);
      expect(timer().currentArcher, Archer.b);
      expect(timer().currentArrow, 1);
      expect(timer().remainingTime, passage);

      // Back to A, now on the second arrow.
      await tester.pump(passage);
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 2);

      stop();
    });

    testWidgets('ends after both archers have shot every arrow', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();

      // 10s preparation + 6 passages of 20s. One second short of that the
      // last passage is still running — the chain must not lose time.
      await tester.pump(const Duration(seconds: 129));
      expect(timer().phase, TimerPhase.active);
      expect(timer().currentArcher, Archer.b);
      expect(timer().currentArrow, 3);

      await tester.pump(const Duration(seconds: 1));
      expect(timer().phase, TimerPhase.ended);
      expect(timer().isRunning, isFalse);
    });

    testWidgets('advance jumps to the next archer with a full passage', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 15)); // 5s into A's passage

      expect(timer().currentArcher, Archer.a);

      // The observer saw the arrow leave the bow: the rest of the time is
      // dropped and B gets the full 20s from now.
      notifier().advance();
      expect(timer().currentArcher, Archer.b);
      expect(timer().remainingTime, passage);

      await tester.pump(const Duration(seconds: 20));
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 2);

      stop();
    });

    testWidgets('advance in the last passage ends the round', (tester) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 115)); // B's third arrow

      expect(timer().currentArcher, Archer.b);
      expect(timer().currentArrow, 3);

      notifier().advance();
      expect(timer().phase, TimerPhase.ended);
    });

    testWidgets('warns only in the last 5s of a passage', (tester) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 10));

      expect(timer().isInWarningPeriod, isFalse);

      await tester.pump(const Duration(seconds: 15));
      expect(timer().remainingTime, const Duration(seconds: 5));
      expect(timer().isInWarningPeriod, isTrue);

      // The handover clears it again — the next archer starts on green.
      await tester.pump(const Duration(seconds: 5));
      expect(timer().currentArcher, Archer.b);
      expect(timer().isInWarningPeriod, isFalse);

      stop();
    });

    testWidgets('takes the arrow count from the settings', (tester) async {
      container.read(settingsProvider.notifier).setAlternatingArrows(1);
      notifier().setMode(TimerMode.alternating);

      expect(timer().arrowsPerArcher, 1);

      notifier().startTimer();
      // 10s preparation + one passage each.
      await tester.pump(const Duration(seconds: 49));
      expect(timer().phase, TimerPhase.active);
      expect(timer().currentArcher, Archer.b);

      await tester.pump(const Duration(seconds: 1));
      expect(timer().phase, TimerPhase.ended);

      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('takes the preparation time from the settings', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCustomPrepTime(const Duration(seconds: 20));
      notifier().setMode(TimerMode.alternating);

      expect(timer().preparationTime, const Duration(seconds: 20));

      notifier().startTimer();
      await tester.pump(const Duration(seconds: 20));
      expect(timer().phase, TimerPhase.active);
      expect(timer().currentArcher, Archer.a);

      stop();
      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('a changed arrow count sets the round up again', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 35)); // mid-round

      container.read(settingsProvider.notifier).setAlternatingArrows(2);

      expect(timer().arrowsPerArcher, 2);
      expect(timer().phase, TimerPhase.idle);
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 1);

      await tester.pump(const Duration(milliseconds: 400)); // debounced save
    });

    testWidgets('reset returns to archer A and the first arrow', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 35)); // B, first arrow

      expect(timer().currentArcher, Archer.b);

      notifier().resetTimer();
      expect(timer().phase, TimerPhase.idle);
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 1);
    });

    testWidgets('pausing freezes the passage of the current archer', (
      tester,
    ) async {
      notifier().setMode(TimerMode.alternating);
      notifier().startTimer();
      await tester.pump(const Duration(seconds: 35)); // 5s into B's passage

      notifier().pauseTimer();
      expect(timer().currentArcher, Archer.b);
      expect(timer().remainingTime, const Duration(seconds: 15));

      await tester.pump(const Duration(seconds: 30));
      expect(timer().currentArcher, Archer.b);

      notifier().startTimer();
      await tester.pump(const Duration(seconds: 15));
      expect(timer().currentArcher, Archer.a);
      expect(timer().currentArrow, 2);

      stop();
    });
  });
}
