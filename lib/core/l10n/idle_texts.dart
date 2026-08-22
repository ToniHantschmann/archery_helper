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

  // Uhrzeit und Datum stehen nicht hier, sondern in `ClockTexts`: die
  // Ruheanzeige ist nicht mehr die einzige Anzeige, die sie braucht, und
  // `WallClockFace` holt sie sich von dort selbst.
}

// ===== PROVIDER =====

final idleTextsProvider = Provider<IdleTexts>((ref) {
  return IdleTexts(ref.watch(languageProvider));
});
