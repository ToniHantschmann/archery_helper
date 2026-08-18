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

  static const _competition = LocalizedText(
    de: 'Wettkampf',
    en: 'Competition',
  );

  static const _competitionDescription = LocalizedText(
    de: 'Qualifikationsrunde mit Passen',
    en: 'Qualification round with ends',
  );

  static const _timerSettings = LocalizedText(
    de: 'Ampel-Einstellungen',
    en: 'Timer Settings',
  );

  static const _timerSettingsDescription = LocalizedText(
    de: 'Modi und Zeiten der Ampel',
    en: 'Timer modes and times',
  );

  static const _competitionSettings = LocalizedText(
    de: 'Wettkampf-Einstellungen',
    en: 'Competition Settings',
  );

  static const _competitionSettingsDescription = LocalizedText(
    de: 'Disziplin, Passen und Aufstellung',
    en: 'Discipline, ends and lineup',
  );

  static const _generalSettings = LocalizedText(
    de: 'Allgemein',
    en: 'General',
  );

  static const _generalSettingsDescription = LocalizedText(
    de: 'Sprache und Ton',
    en: 'Language and sound',
  );

  static const _idle = LocalizedText(de: 'Ruheanzeige', en: 'Standby');

  static const _idleDescription = LocalizedText(
    de: 'Große Uhr, wenn nicht geschossen wird',
    en: 'Large clock while nobody is shooting',
  );

  // ===== HINTS =====

  static const _hintSelect = LocalizedText(de: 'Auswählen', en: 'Select');

  static const _hintOpen = LocalizedText(de: 'Öffnen', en: 'Open');

  // ===== PUBLIC GETTERS =====

  String get title => _title.get(_language);
  String get subtitle => _subtitle.get(_language);

  String get timer => _timer.get(_language);
  String get timerDescription => _timerDescription.get(_language);
  String get competition => _competition.get(_language);
  String get competitionDescription => _competitionDescription.get(_language);
  String get timerSettings => _timerSettings.get(_language);
  String get timerSettingsDescription =>
      _timerSettingsDescription.get(_language);
  String get competitionSettings => _competitionSettings.get(_language);
  String get competitionSettingsDescription =>
      _competitionSettingsDescription.get(_language);
  String get generalSettings => _generalSettings.get(_language);
  String get generalSettingsDescription =>
      _generalSettingsDescription.get(_language);
  String get idle => _idle.get(_language);
  String get idleDescription => _idleDescription.get(_language);

  String get hintSelect => _hintSelect.get(_language);
  String get hintOpen => _hintOpen.get(_language);
}

// ===== PROVIDER =====

final menuTextsProvider = Provider<MenuTexts>((ref) {
  return MenuTexts(ref.watch(languageProvider));
});
