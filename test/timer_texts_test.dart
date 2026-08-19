import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/core/l10n/timer_texts.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The countdown ticks every 100ms, so the seconds display has to round up:
/// otherwise every value would be replaced 100ms after it appeared and the
/// starting value would be skipped entirely. These tests pin the rounding
/// boundaries — that is where an off-by-one second hides.
void main() {
  String format(Duration d) => TimerTexts.formatTime(d);

  String formatWithMillis(Duration d) =>
      TimerTexts.formatTime(d, showMilliseconds: true);

  group('seconds display', () {
    test('shows the starting value for a full second', () {
      expect(format(const Duration(seconds: 120)), '2:00');
      expect(format(const Duration(milliseconds: 119900)), '2:00');
      expect(format(const Duration(milliseconds: 119100)), '2:00');
      // One second after the start the display moves on.
      expect(format(const Duration(milliseconds: 119000)), '1:59');
    });

    test('shows 0:00 only when the time is really up', () {
      expect(format(const Duration(milliseconds: 1000)), '0:01');
      expect(format(const Duration(milliseconds: 100)), '0:01');
      expect(format(Duration.zero), '0:00');
    });

    test('rolls over the minute at the right moment', () {
      expect(format(const Duration(milliseconds: 60100)), '1:01');
      expect(format(const Duration(seconds: 60)), '1:00');
      expect(format(const Duration(milliseconds: 59900)), '1:00');
      expect(format(const Duration(milliseconds: 59000)), '0:59');
    });

    test('pads the seconds to two digits', () {
      expect(format(const Duration(seconds: 65)), '1:05');
      expect(format(const Duration(seconds: 9)), '0:09');
    });

    test('handles durations without a minute part', () {
      expect(format(const Duration(seconds: 45)), '0:45');
      expect(format(const Duration(seconds: 240)), '4:00');
    });
  });

  group('tenths display', () {
    test('shows the exact remaining time instead of rounding up', () {
      // With tenths on screen, rounding up would contradict what is shown.
      expect(formatWithMillis(const Duration(seconds: 120)), '2:00.0');
      expect(formatWithMillis(const Duration(milliseconds: 119900)), '1:59.9');
      expect(formatWithMillis(const Duration(milliseconds: 100)), '0:00.1');
      expect(formatWithMillis(Duration.zero), '0:00.0');
    });
  });

  /// „240" statt „4:00" ist reine Schreibweise: dieselbe Zahl wechselt zum
  /// selben Zeitpunkt, sonst würde die Einstellung die Kante verschieben, auf
  /// die der Timer sein nächstes Update plant.
  group('seconds-only format', () {
    String formatSeconds(Duration d) =>
        TimerTexts.formatTime(d, format: TimeFormat.seconds);

    String formatSecondsWithMillis(Duration d) => TimerTexts.formatTime(
      d,
      showMilliseconds: true,
      format: TimeFormat.seconds,
    );

    test('drops the minute part and never pads', () {
      expect(formatSeconds(const Duration(seconds: 240)), '240');
      expect(formatSeconds(const Duration(seconds: 65)), '65');
      expect(formatSeconds(const Duration(seconds: 9)), '9');
      expect(formatSeconds(Duration.zero), '0');
    });

    test('rounds up on exactly the same boundaries as the minute format', () {
      for (final ms in [120000, 119900, 119100, 119000, 1000, 100, 0]) {
        final d = Duration(milliseconds: ms);
        final minutes = format(d).split(':');
        final expected = int.parse(minutes[0]) * 60 + int.parse(minutes[1]);
        expect(formatSeconds(d), '$expected', reason: '$ms ms');
      }
    });

    test('keeps the tenths when milliseconds are on', () {
      expect(formatSecondsWithMillis(const Duration(seconds: 120)), '120.0');
      expect(
        formatSecondsWithMillis(const Duration(milliseconds: 119900)),
        '119.9',
      );
      expect(formatSecondsWithMillis(const Duration(milliseconds: 100)), '0.1');
      expect(formatSecondsWithMillis(Duration.zero), '0.0');
    });
  });

  group('alternating mode wording', () {
    const de = TimerTexts(AppLanguage.german);
    const en = TimerTexts(AppLanguage.english);

    TimerState state({
      required TimerPhase phase,
      Archer archer = Archer.a,
      bool isPaused = false,
    }) {
      return TimerState(
        remainingTime: const Duration(seconds: 20),
        phase: phase,
        mode: TimerMode.alternating,
        isPaused: isPaused,
        preparationTime: const Duration(seconds: 10),
        mainTime: const Duration(seconds: 20),
        warningThreshold: const Duration(seconds: 5),
        currentArcher: archer,
        arrowsPerArcher: 3,
      );
    }

    test('names the archer instead of the phase while shooting', () {
      expect(
        de.getPhaseTextEnhanced(state(phase: TimerPhase.active)),
        'Schütze A',
      );
      expect(
        de.getPhaseTextEnhanced(
          state(phase: TimerPhase.active, archer: Archer.b),
        ),
        'Schütze B',
      );
      expect(
        en.getPhaseTextEnhanced(state(phase: TimerPhase.active)),
        'Archer A',
      );
    });

    test('names the archer during the preparation too', () {
      expect(
        de.getPhaseTextEnhanced(state(phase: TimerPhase.preparation)),
        'Vorbereitung A',
      );
      expect(
        en.getPhaseTextEnhanced(state(phase: TimerPhase.preparation)),
        'Preparation A',
      );
    });

    test('keeps the round-wide wording for idle and ended', () {
      // Neither belongs to one of the two archers.
      expect(de.getPhaseTextEnhanced(state(phase: TimerPhase.idle)), 'Bereit');
      expect(de.getPhaseTextEnhanced(state(phase: TimerPhase.ended)), 'Beendet');
    });

    test('still marks a paused round', () {
      expect(
        de.getPhaseTextEnhanced(
          state(phase: TimerPhase.preparation, isPaused: true),
        ),
        'Vorbereitung A (Pausiert)',
      );
    });

    test('counts the arrows', () {
      expect(de.arrowCounter(2, 3), 'Pfeil 2/3');
      expect(en.arrowCounter(2, 3), 'Arrow 2/3');
    });
  });
}
