import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'app_language.dart';

/// Localized texts for the menu screen.
class MenuTexts {
  final AppLanguage _language;

  const MenuTexts(this._language);

  // ===== HEADER =====

  static const _title = LocalizedText(de: 'Bogenampel', en: 'Archery Light');

  static const _subtitle = LocalizedText(
    de: 'Helfer für den Schießtunnel',
    en: 'Helpers for the shooting tunnel',
  );

  // ===== ENTRIES =====

  static const _timer = LocalizedText(de: 'Timer', en: 'Timer');

  static const _timerDescription = LocalizedText(
    de: 'Schießzeit und Ampel',
    en: 'Shooting time and traffic light',
  );

  static const _settings = LocalizedText(
    de: 'Einstellungen',
    en: 'Settings',
  );

  static const _settingsDescription = LocalizedText(
    de: 'Sprache, Ton und Zeiten',
    en: 'Language, sound and times',
  );

  static const _idle = LocalizedText(de: 'Ruheanzeige', en: 'Standby');

  static const _idleDescription = LocalizedText(
    de: 'Große Uhr, wenn nicht geschossen wird',
    en: 'Large clock while nobody is shooting',
  );

  // ===== HINTS =====

  static const _hintSelect = LocalizedText(de: 'Auswählen', en: 'Select');

  static const _hintOpen = LocalizedText(de: 'Öffnen', en: 'Open');

  static const _hintBack = LocalizedText(de: 'Zurück', en: 'Back');

  // ===== PUBLIC GETTERS =====

  String get title => _title.get(_language);
  String get subtitle => _subtitle.get(_language);

  String get timer => _timer.get(_language);
  String get timerDescription => _timerDescription.get(_language);
  String get settings => _settings.get(_language);
  String get settingsDescription => _settingsDescription.get(_language);
  String get idle => _idle.get(_language);
  String get idleDescription => _idleDescription.get(_language);

  String get hintSelect => _hintSelect.get(_language);
  String get hintOpen => _hintOpen.get(_language);
  String get hintBack => _hintBack.get(_language);
}

// ===== PROVIDER =====

final menuTextsProvider = Provider<MenuTexts>((ref) {
  return MenuTexts(ref.watch(languageProvider));
});
