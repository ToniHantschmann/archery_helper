import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'app_language.dart';

/// Localized texts for the idle (standby) screen.
class IdleTexts {
  final AppLanguage _language;

  const IdleTexts(this._language);

  static const _title = LocalizedText(de: 'Bogenampel', en: 'Archery Light');

  static const _subtitle = LocalizedText(
    de: 'Schießtunnel',
    en: 'Shooting tunnel',
  );

  static const _wakeHint = LocalizedText(
    de: 'Taste drücken zum Fortfahren',
    en: 'Press a key to continue',
  );

  String get title => _title.get(_language);
  String get subtitle => _subtitle.get(_language);
  String get wakeHint => _wakeHint.get(_language);

  /// Wall clock, always 24h — this is a German club and a 12h clock would be
  /// ambiguous on a display nobody interacts with.
  String formatClock(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// Numeric date, in the order the language expects. Deliberately without
  /// weekday or month names: two more translation tables for something that is
  /// read at a glance would not earn their keep.
  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    switch (_language) {
      case AppLanguage.german:
        return '$day.$month.${date.year}';
      case AppLanguage.english:
        return '${date.year}-$month-$day';
    }
  }
}

// ===== PROVIDER =====

final idleTextsProvider = Provider<IdleTexts>((ref) {
  return IdleTexts(ref.watch(languageProvider));
});
