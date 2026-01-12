import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/timer_state.dart';
import 'app_language.dart';
import '../../providers/settings_provider.dart'; // GEÄNDERT

/// Localized texts for the settings screen
class SettingsTexts {
  final AppLanguage _currentLanguage;

  const SettingsTexts(this._currentLanguage);

  // ===== SCREEN TITLE =====

  static const _screenTitle = LocalizedText(
    de: 'Einstellungen',
    en: 'Settings',
  );

  // ===== SECTION HEADERS =====

  static const _soundSection = LocalizedText(de: 'Ton', en: 'Sound');

  static const _timerSection = LocalizedText(de: 'Timer', en: 'Timer');

  static const _customTimesSection = LocalizedText(
    de: 'Benutzerdefinierte Zeiten',
    en: 'Custom Times',
  );

  static const _languageSection = LocalizedText(de: 'Sprache', en: 'Language');

  // ===== SOUND SETTINGS =====

  static const _soundEnabled = LocalizedText(
    de: 'Ton aktivieren',
    en: 'Enable Sound',
  );

  static const _volume = LocalizedText(de: 'Lautstärke', en: 'Volume');

  // ===== TIMER SETTINGS =====

  static const _defaultMode = LocalizedText(
    de: 'Standard-Modus',
    en: 'Default Mode',
  );

  static const _autoStart = LocalizedText(de: 'Auto-Start', en: 'Auto-Start');

  static const _autoStartSubtitle = LocalizedText(
    de: 'Timer automatisch starten',
    en: 'Start timer automatically',
  );

  static const _showMilliseconds = LocalizedText(
    de: 'Millisekunden anzeigen',
    en: 'Show Milliseconds',
  );

  // ===== LANGUAGE SETTINGS =====

  static const _language = LocalizedText(de: 'Sprache', en: 'Language');

  static const _german = LocalizedText(de: 'Deutsch', en: 'German');

  static const _english = LocalizedText(de: 'Englisch', en: 'English');

  // ===== CUSTOM TIMES =====

  static const _preparationTime = LocalizedText(
    de: 'Vorbereitungszeit',
    en: 'Preparation Time',
  );

  static const _mainTime = LocalizedText(de: 'Hauptzeit', en: 'Main Time');

  // ===== BUTTONS =====

  static const _resetToDefaults = LocalizedText(
    de: 'Auf Standard zurücksetzen',
    en: 'Reset to Defaults',
  );

  // ===== DIALOG =====

  static const _resetDialogTitle = LocalizedText(
    de: 'Einstellungen zurücksetzen',
    en: 'Reset Settings',
  );

  static const _resetDialogContent = LocalizedText(
    de:
        'Möchten Sie wirklich alle Einstellungen auf die Standardwerte zurücksetzen?',
    en: 'Do you really want to reset all settings to default values?',
  );

  static const _cancel = LocalizedText(de: 'Abbrechen', en: 'Cancel');

  static const _reset = LocalizedText(de: 'Zurücksetzen', en: 'Reset');

  // ===== FEEDBACK =====

  static const _settingsReset = LocalizedText(
    de: 'Einstellungen wurden zurückgesetzt',
    en: 'Settings have been reset',
  );

  // ===== UNITS =====

  static const _seconds = LocalizedText(de: 'Sekunden', en: 'Seconds');

  static const _secondsShort = LocalizedText(de: 's', en: 's');

  // ===== TIMER MODE NAMES =====

  static const _indoor = LocalizedText(de: 'Indoor', en: 'Indoor');

  static const _outdoor = LocalizedText(de: 'Outdoor', en: 'Outdoor');

  static const _custom = LocalizedText(de: 'Benutzerdefiniert', en: 'Custom');

  static const _alternating = LocalizedText(
    de: 'Wechsel (20s)',
    en: 'Alternating (20s)',
  );

  static const _trafficLight = LocalizedText(de: 'Ampel', en: 'Traffic Light');

  // ===== PUBLIC GETTERS =====

  String get screenTitle => _screenTitle.get(_currentLanguage);

  String get soundSection => _soundSection.get(_currentLanguage);
  String get timerSection => _timerSection.get(_currentLanguage);
  String get customTimesSection => _customTimesSection.get(_currentLanguage);
  String get languageSection => _languageSection.get(_currentLanguage);

  String get soundEnabled => _soundEnabled.get(_currentLanguage);
  String get volume => _volume.get(_currentLanguage);

  String get defaultMode => _defaultMode.get(_currentLanguage);
  String get autoStart => _autoStart.get(_currentLanguage);
  String get autoStartSubtitle => _autoStartSubtitle.get(_currentLanguage);
  String get showMilliseconds => _showMilliseconds.get(_currentLanguage);

  String get language => _language.get(_currentLanguage);
  String get german => _german.get(_currentLanguage);
  String get english => _english.get(_currentLanguage);

  String get preparationTime => _preparationTime.get(_currentLanguage);
  String get mainTime => _mainTime.get(_currentLanguage);

  String get resetToDefaultsButton => _resetToDefaults.get(_currentLanguage);

  String get resetDialogTitle => _resetDialogTitle.get(_currentLanguage);
  String get resetDialogContent => _resetDialogContent.get(_currentLanguage);
  String get cancelButton => _cancel.get(_currentLanguage);
  String get resetButton => _reset.get(_currentLanguage);

  String get settingsResetSnackbar => _settingsReset.get(_currentLanguage);

  String get seconds => _seconds.get(_currentLanguage);
  String get secondsShort => _secondsShort.get(_currentLanguage);

  // ===== HELPER METHODS =====

  /// Get the display name for a timer mode
  String getModeName(TimerMode mode) {
    switch (mode) {
      case TimerMode.indoor:
        return _indoor.get(_currentLanguage);
      case TimerMode.outdoor:
        return _outdoor.get(_currentLanguage);
      case TimerMode.custom:
        return _custom.get(_currentLanguage);
      case TimerMode.alternating:
        return _alternating.get(_currentLanguage);
      case TimerMode.trafficLight:
        return _trafficLight.get(_currentLanguage);
    }
  }

  /// Get the display name for a language
  String getLanguageName(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.german:
        return _german.get(_currentLanguage);
      case AppLanguage.english:
        return _english.get(_currentLanguage);
    }
  }

  /// Format a duration for display (e.g., "120 Sekunden")
  String formatDurationDisplay(Duration duration) {
    return '${duration.inSeconds} $seconds';
  }

  /// Format a percentage value (e.g., "80%")
  String formatPercentage(double value) {
    return '${(value * 100).round()}%';
  }
}

// ===== PROVIDER =====

/// Provider for localized settings texts based on current language from settings
final settingsTextsProvider = Provider<SettingsTexts>((ref) {
  final language = ref.watch(
    languageProvider,
  ); // Nutzt jetzt languageProvider aus settings_provider
  return SettingsTexts(language);
});
