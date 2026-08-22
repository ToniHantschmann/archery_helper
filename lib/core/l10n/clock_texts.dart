import 'app_language.dart';

/// Uhrzeit und Datum als Zeichenkette.
///
/// Statisch und ohne Provider, wie `TimerTexts.formatTime`: das hier ist keine
/// Sprache eines Screens, sondern eine Umrechnung, die zwei Screens gleich
/// brauchen — die Ruheanzeige und die Uhrzeitanzeige des Wettkampfs. Stünde sie
/// bei einem der beiden, müsste der andere ihn importieren, um an eine Zahl zu
/// kommen, die mit ihm nichts zu tun hat.
class ClockTexts {
  const ClockTexts._();

  /// Wall clock, always 24h — this is a German club and a 12h clock would be
  /// ambiguous on a display nobody interacts with.
  static String formatClock(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// Numeric date, in the order the language expects. Deliberately without
  /// weekday or month names: two more translation tables for something that is
  /// read at a glance would not earn their keep.
  static String formatDate(DateTime date, AppLanguage language) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    switch (language) {
      case AppLanguage.german:
        return '$day.$month.${date.year}';
      case AppLanguage.english:
        return '${date.year}-$month-$day';
    }
  }
}
