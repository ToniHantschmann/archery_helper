import 'package:archery_helper/core/l10n/timer_texts.dart';
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
}
