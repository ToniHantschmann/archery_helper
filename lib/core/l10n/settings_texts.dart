import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/signal_tone.dart';
import '../../models/competition_state.dart';
import '../../models/settings.dart';
import '../../models/settings_section.dart';
import '../../models/timer_state.dart';
import 'app_language.dart';
import 'timer_texts.dart';
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

  static const _generalTitle = LocalizedText(
    de: 'Allgemein',
    en: 'General',
  );

  static const _timerTitle = LocalizedText(
    de: 'Ampel-Einstellungen',
    en: 'Timer Settings',
  );

  static const _competitionTitle = LocalizedText(
    de: 'Wettkampf-Einstellungen',
    en: 'Competition Settings',
  );

  // ===== SECTION HEADERS =====

  static const _soundSection = LocalizedText(de: 'Ton', en: 'Sound');

  static const _timerSection = LocalizedText(de: 'Timer', en: 'Timer');

  static const _customTimesSection = LocalizedText(
    de: 'Benutzerdefinierte Zeiten',
    en: 'Custom Times',
  );

  static const _languageSection = LocalizedText(de: 'Sprache', en: 'Language');

  static const _roundSection = LocalizedText(de: 'Runde', en: 'Round');

  static const _targetSection = LocalizedText(de: 'Scheibe', en: 'Target');

  static const _displaySection = LocalizedText(de: 'Anzeige', en: 'Display');

  // ===== WETTKAMPF =====

  static const _discipline = LocalizedText(de: 'Disziplin', en: 'Discipline');

  static const _disciplineSubtitle = LocalizedText(
    de: 'Pfeile und Schusszeit einer Passe',
    en: 'Arrows and shooting time per end',
  );

  static const _ends = LocalizedText(de: 'Passen', en: 'Ends');

  static const _endsSubtitle = LocalizedText(
    de: 'Wie viele Passen geschossen werden',
    en: 'How many ends are shot',
  );

  static const _lineup = LocalizedText(de: 'Aufstellung', en: 'Lineup');

  static const _lineupSubtitle = LocalizedText(
    de: 'Wer nacheinander an die Scheibe geht',
    en: 'Who takes the line one after another',
  );

  static const _lineupAbcd = LocalizedText(de: 'AB / CD', en: 'AB / CD');

  static const _lineupAb = LocalizedText(de: 'A / B', en: 'A / B');

  static const _lineupSingle = LocalizedText(de: 'Alle', en: 'All');

  static const _display = LocalizedText(de: 'Ausgabe', en: 'Output');

  static const _displaySubtitle = LocalizedText(
    de: 'LED-Wand: 120 × 80 Pixel oben links, Skalierung 100 %',
    en: 'LED panel: 120 × 80 pixels at the top left, 100 % scaling',
  );

  static const _displayStandard = LocalizedText(de: 'Monitor', en: 'Monitor');

  static const _displayLedPreview = LocalizedText(
    de: 'LED-Vorschau',
    en: 'LED preview',
  );

  static const _displayLed = LocalizedText(de: 'LED-Wand', en: 'LED panel');

  /// Setzt gespiegelte Bildschirme voraus — das muss dort stehen, wo man den
  /// Wert auswählt, sonst sitzt der Ausschnitt am Turniertag auf dem falschen
  /// Bild.
  static const _displayLedWithControl = LocalizedText(
    de: 'LED-Wand + Bedienung (gespiegelt)',
    en: 'LED panel + control (mirrored)',
  );

  static const _arrows = LocalizedText(de: 'Pfeile', en: 'arrows');

  static const _indoorDiscipline = LocalizedText(de: 'Halle', en: 'Indoor');

  static const _outdoorDiscipline = LocalizedText(
    de: 'Freiluft',
    en: 'Outdoor',
  );

  // ===== SOUND SETTINGS =====

  static const _soundEnabled = LocalizedText(
    de: 'Ton aktivieren',
    en: 'Enable Sound',
  );

  static const _signalTone = LocalizedText(de: 'Signalton', en: 'Signal tone');

  /// Steht unter der Signalton-Zeile: die beiden Namen sagen nicht, wozu man
  /// den zweiten nimmt.
  static const _signalToneSubtitle = LocalizedText(
    de: 'Ton 2 klingt heller und trägt draußen weiter',
    en: 'Tone 2 is brighter and carries further outdoors',
  );

  static const _signalToneOne = LocalizedText(de: 'Ton 1', en: 'Tone 1');
  static const _signalToneTwo = LocalizedText(de: 'Ton 2', en: 'Tone 2');

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

  static const _timeFormat = LocalizedText(de: 'Zeitformat', en: 'Time Format');

  // Das Beispiel steht im Namen: von der Schießlinie aus ist „Minuten (4:00)"
  // sofort zu verstehen, „Minuten" allein nicht.
  static const _timeFormatMinutes = LocalizedText(
    de: 'Minuten (4:00)',
    en: 'Minutes (4:00)',
  );

  static const _timeFormatSeconds = LocalizedText(
    de: 'Sekunden (240)',
    en: 'Seconds (240)',
  );

  // 100 % ist kein „aus", sondern der Punkt, an dem die Uhr die Fläche genau
  // ausfüllt — das steht im Untertitel, weil sonst niemand weiß, wogegen er
  // stellt.
  static const _displayScale = LocalizedText(
    de: 'Anzeigegröße',
    en: 'Display size',
  );

  static const _displayScaleSubtitle = LocalizedText(
    de: 'Uhr und Phasenwort, 100 % = füllt die Fläche',
    en: 'Clock and phase word, 100% = fills the area',
  );

  static const _arrowsPerArcher = LocalizedText(
    de: 'Pfeile pro Schütze',
    en: 'Arrows per Archer',
  );

  static const _arrowsPerArcherSubtitle = LocalizedText(
    de: 'Nur im Wechsel-Timer',
    en: 'Alternating timer only',
  );

  // ===== LANGUAGE SETTINGS =====

  static const _language = LocalizedText(de: 'Sprache', en: 'Language');

  static const _german = LocalizedText(de: 'Deutsch', en: 'German');

  static const _english = LocalizedText(de: 'Englisch', en: 'English');

  // ===== DISPLAY SETTINGS =====

  static const _fullscreen = LocalizedText(de: 'Vollbild', en: 'Fullscreen');

  static const _fullscreenNote = LocalizedText(
    de: 'Auch mit F11 umschaltbar',
    en: 'Also toggled with F11',
  );

  // ===== CUSTOM TIMES =====

  static const _preparationTime = LocalizedText(
    de: 'Vorbereitungszeit',
    en: 'Preparation Time',
  );

  static const _preparationTimeSubtitle = LocalizedText(
    de: 'Gilt auch für den Wechsel-Timer',
    en: 'Also used by the alternating timer',
  );

  static const _mainTime = LocalizedText(de: 'Hauptzeit', en: 'Main Time');

  // ===== BUTTONS =====

  static const _resetToDefaults = LocalizedText(
    de: 'Auf Standard zurücksetzen',
    en: 'Reset to Defaults',
  );

  // ===== RESET CONFIRMATION =====

  static const _resetDialogTitle = LocalizedText(
    de: 'Einstellungen zurücksetzen',
    en: 'Reset Settings',
  );

  static const _resetDialogContent = LocalizedText(
    de:
        'Möchten Sie die Einstellungen dieses Bereichs wirklich auf die '
        'Standardwerte zurücksetzen?',
    en:
        'Do you really want to reset the settings on this screen to their '
        'default values?',
  );

  static const _cancel = LocalizedText(de: 'Abbrechen', en: 'Cancel');

  static const _reset = LocalizedText(de: 'Zurücksetzen', en: 'Reset');

  // ===== KEYBOARD NAVIGATION =====

  static const _navHintSelect = LocalizedText(
    de: '↑↓ Auswählen',
    en: '↑↓ Select',
  );

  static const _navHintChange = LocalizedText(
    de: '←→ Ändern',
    en: '←→ Change',
  );

  static const _navHintConfirm = LocalizedText(
    de: 'Enter/Leertaste Bestätigen',
    en: 'Enter/Space Confirm',
  );

  static const _navHintBack = LocalizedText(de: 'Esc Zurück', en: 'Esc Back');

  /// Labels for the key hint rail. Unlike the `_navHint*` entries above these
  /// carry no key symbols: the rail draws the keys as caps and takes the
  /// binding from the (remappable) keyboard config.
  static const _labelSelect = LocalizedText(de: 'Auswählen', en: 'Select');

  static const _labelChange = LocalizedText(de: 'Ändern', en: 'Change');

  static const _labelConfirm = LocalizedText(de: 'Bestätigen', en: 'Confirm');

  static const _labelBack = LocalizedText(de: 'Zurück', en: 'Back');

  // ===== VALUE LABELS =====

  static const _on = LocalizedText(de: 'An', en: 'On');

  static const _off = LocalizedText(de: 'Aus', en: 'Off');

  /// Shown on the volume row while sound is switched off — the row is skipped
  /// by the keyboard, so it has to say why it cannot be reached.
  static const _soundOffNote = LocalizedText(
    de: 'Ton ist ausgeschaltet',
    en: 'Sound is switched off',
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

  /// Titel des Einstellungs-Screens eines Bereichs.
  String sectionTitle(SettingsSection section) {
    switch (section) {
      case SettingsSection.general:
        return _generalTitle.get(_currentLanguage);
      case SettingsSection.timer:
        return _timerTitle.get(_currentLanguage);
      case SettingsSection.competition:
        return _competitionTitle.get(_currentLanguage);
    }
  }

  String get soundSection => _soundSection.get(_currentLanguage);
  String get timerSection => _timerSection.get(_currentLanguage);
  String get customTimesSection => _customTimesSection.get(_currentLanguage);
  String get languageSection => _languageSection.get(_currentLanguage);
  String get roundSection => _roundSection.get(_currentLanguage);
  String get targetSection => _targetSection.get(_currentLanguage);
  String get displaySection => _displaySection.get(_currentLanguage);

  String get discipline => _discipline.get(_currentLanguage);
  String get disciplineSubtitle => _disciplineSubtitle.get(_currentLanguage);
  String get ends => _ends.get(_currentLanguage);
  String get endsSubtitle => _endsSubtitle.get(_currentLanguage);
  String get lineup => _lineup.get(_currentLanguage);
  String get lineupSubtitle => _lineupSubtitle.get(_currentLanguage);
  String get display => _display.get(_currentLanguage);
  String get displaySubtitle => _displaySubtitle.get(_currentLanguage);

  String get soundEnabled => _soundEnabled.get(_currentLanguage);
  String get signalTone => _signalTone.get(_currentLanguage);
  String get signalToneSubtitle => _signalToneSubtitle.get(_currentLanguage);
  String get volume => _volume.get(_currentLanguage);

  String get defaultMode => _defaultMode.get(_currentLanguage);
  String get autoStart => _autoStart.get(_currentLanguage);
  String get autoStartSubtitle => _autoStartSubtitle.get(_currentLanguage);
  String get showMilliseconds => _showMilliseconds.get(_currentLanguage);
  String get timeFormat => _timeFormat.get(_currentLanguage);

  String get language => _language.get(_currentLanguage);
  String get german => _german.get(_currentLanguage);
  String get english => _english.get(_currentLanguage);

  String get fullscreen => _fullscreen.get(_currentLanguage);
  String get fullscreenNote => _fullscreenNote.get(_currentLanguage);

  String get displayScale => _displayScale.get(_currentLanguage);
  String get displayScaleSubtitle =>
      _displayScaleSubtitle.get(_currentLanguage);
  String get arrowsPerArcher => _arrowsPerArcher.get(_currentLanguage);
  String get arrowsPerArcherSubtitle =>
      _arrowsPerArcherSubtitle.get(_currentLanguage);
  String get preparationTime => _preparationTime.get(_currentLanguage);
  String get preparationTimeSubtitle =>
      _preparationTimeSubtitle.get(_currentLanguage);
  String get mainTime => _mainTime.get(_currentLanguage);

  String get resetToDefaultsButton => _resetToDefaults.get(_currentLanguage);

  String get resetDialogTitle => _resetDialogTitle.get(_currentLanguage);
  String get resetDialogContent => _resetDialogContent.get(_currentLanguage);
  String get cancelButton => _cancel.get(_currentLanguage);
  String get resetButton => _reset.get(_currentLanguage);

  String get navHintSelect => _navHintSelect.get(_currentLanguage);
  String get navHintChange => _navHintChange.get(_currentLanguage);
  String get navHintConfirm => _navHintConfirm.get(_currentLanguage);
  String get navHintBack => _navHintBack.get(_currentLanguage);

  /// The full keyboard hint line shown at the bottom of the settings screen
  String get navigationHint =>
      '$navHintSelect   ·   $navHintChange   ·   $navHintConfirm   ·   $navHintBack';

  String get labelSelect => _labelSelect.get(_currentLanguage);
  String get labelChange => _labelChange.get(_currentLanguage);
  String get labelConfirm => _labelConfirm.get(_currentLanguage);
  String get labelBack => _labelBack.get(_currentLanguage);

  String get on => _on.get(_currentLanguage);
  String get off => _off.get(_currentLanguage);
  String get soundOffNote => _soundOffNote.get(_currentLanguage);

  /// "An" / "Aus" for a boolean setting.
  String onOff(bool value) => value ? on : off;

  String get seconds => _seconds.get(_currentLanguage);
  String get secondsShort => _secondsShort.get(_currentLanguage);

  // ===== HELPER METHODS =====

  /// Get the display name for a timer mode
  /// Anzeigename einer Disziplin.
  String getDisciplineName(CompetitionDiscipline discipline) {
    switch (discipline) {
      case CompetitionDiscipline.indoor:
        return _indoorDiscipline.get(_currentLanguage);
      case CompetitionDiscipline.outdoor:
        return _outdoorDiscipline.get(_currentLanguage);
    }
  }

  /// Was die Disziplin konkret bedeutet: „3 Pfeile · 2:00".
  ///
  /// Steht als Unterzeile unter der Disziplin, statt einer festen Erklärung —
  /// die Zahlen sind der eigentliche Inhalt der Einstellung, und wer sie sieht,
  /// muss nicht wissen, was „Halle" in den Regeln bedeutet.
  String getDisciplineDetail(CompetitionDiscipline discipline) {
    final arrows = '${discipline.arrowsPerEnd} ${_arrows.get(_currentLanguage)}';
    return '$arrows · ${TimerTexts.formatTime(discipline.shootingTime)}';
  }

  /// Anzeigename einer Aufstellung.
  String getLineupName(CompetitionLineup lineup) {
    switch (lineup) {
      case CompetitionLineup.abcd:
        return _lineupAbcd.get(_currentLanguage);
      case CompetitionLineup.ab:
        return _lineupAb.get(_currentLanguage);
      case CompetitionLineup.single:
        return _lineupSingle.get(_currentLanguage);
    }
  }

  /// Anzeigename einer Ausgabeart.
  String getDisplayName(CompetitionDisplay display) {
    switch (display) {
      case CompetitionDisplay.standard:
        return _displayStandard.get(_currentLanguage);
      case CompetitionDisplay.ledPreview:
        return _displayLedPreview.get(_currentLanguage);
      case CompetitionDisplay.led:
        return _displayLed.get(_currentLanguage);
      case CompetitionDisplay.ledWithControl:
        return _displayLedWithControl.get(_currentLanguage);
    }
  }

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

  /// Wie die Uhr ihre Zahl schreibt — das Beispiel steht im Namen.
  String getTimeFormatName(TimeFormat format) {
    switch (format) {
      case TimeFormat.minutesSeconds:
        return _timeFormatMinutes.get(_currentLanguage);
      case TimeFormat.seconds:
        return _timeFormatSeconds.get(_currentLanguage);
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

  String getSignalToneName(SignalTone tone) {
    switch (tone) {
      case SignalTone.tone1:
        return _signalToneOne.get(_currentLanguage);
      case SignalTone.tone2:
        return _signalToneTwo.get(_currentLanguage);
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
