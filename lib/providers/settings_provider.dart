import 'dart:async';

import 'package:archery_helper/core/audio/signal_tone.dart';
import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/competition_state.dart';
import '../models/settings.dart';
import '../models/settings_section.dart';
import '../models/timer_state.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

// Settings Business Logic Notifier
class SettingsNotifier extends Notifier<Settings> {
  // lazy-loaded repository
  late final SettingsRepository _repository;

  Timer? _saveDebounce;

  /// The state waiting to be written, held separately so [_flush] never has to
  /// touch `state` — that would throw once the notifier is disposed.
  Settings? _pendingSave;

  /// Holding an arrow key in the settings screen changes a value on every key
  /// repeat; without this delay each of those would hit SharedPreferences.
  static const _saveDelay = Duration(milliseconds: 300);

  @override
  Settings build() {
    _repository = ref.watch(settingsRepositoryProvider);
    // Write pending changes instead of dropping them — a value changed less
    // than _saveDelay before shutdown would otherwise be lost.
    ref.onDispose(_flush);
    // initially start with default settings and load real settings later with loadSettings()
    return const Settings();
  }

  /// load settings from repository
  Future<void> loadSettings() async {
    state = await _repository.loadSettings();
  }

  /// save current state (debounced — see [_saveDelay])
  void _save() {
    _pendingSave = state;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDelay, _flush);
  }

  void _flush() {
    _saveDebounce?.cancel();
    _saveDebounce = null;

    final pending = _pendingSave;
    if (pending == null) return;

    _pendingSave = null;
    _repository.saveSettings(pending);
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _save();
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    _save();
  }

  void setSignalTone(SignalTone tone) {
    state = state.copyWith(signalTone: tone);
    _save();
  }

  void setDefaultMode(TimerMode mode) {
    state = state.copyWith(defaultMode: mode);
    _save();
  }

  void toggleShowMilliseconds() {
    state = state.copyWith(showMilliseconds: !state.showMilliseconds);
    _save();
  }

  void setTimeFormat(TimeFormat format) {
    state = state.copyWith(timeFormat: format);
    _save();
  }

  void setCustomPrepTime(Duration duration) {
    state = state.copyWith(customPrepTime: duration);
    _save();
  }

  void setCustomMainTime(Duration duration) {
    state = state.copyWith(customMainTime: duration);
    _save();
  }

  void setAlternatingArrows(int arrows) {
    state = state.copyWith(
      alternatingArrows: arrows.clamp(
        Settings.minAlternatingArrows,
        Settings.maxAlternatingArrows,
      ),
    );
    _save();
  }

  /// Anzeigegröße der Ampel. Die Grenzen sitzen hier und nicht beim Aufrufer,
  /// damit auch der Weg über die Maus nicht daran vorbei kann.
  void setTimerScale(double scale) {
    state = state.copyWith(
      timerScale: scale.clamp(Settings.minTimerScale, Settings.maxTimerScale),
    );
    _save();
  }

  /// Vollbild an/aus. Das Fenster folgt diesem Wert (siehe `main.dart`), F11
  /// und die Einstellungszeile schalten beide hier.
  void toggleFullscreen() {
    state = state.copyWith(fullscreen: !state.fullscreen);
    _save();
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    _save();
  }

  /// Setzt die Disziplin — und mit ihr die Passenzahl.
  ///
  /// Die 20 Passen der Halle und die 12 der Freiluft gehören zur Disziplin, also
  /// kommen sie mit. Danach ist die Passenzahl wieder frei: ein Vereinsformat
  /// schießt auch mal zehn.
  void setCompetitionDiscipline(CompetitionDiscipline discipline) {
    state = state.copyWith(
      competitionDiscipline: discipline,
      competitionEnds: discipline.defaultEnds,
    );
    _save();
  }

  void setCompetitionEnds(int ends) {
    state = state.copyWith(
      competitionEnds: ends.clamp(
        Settings.minCompetitionEnds,
        Settings.maxCompetitionEnds,
      ),
    );
    _save();
  }

  void setCompetitionLineup(CompetitionLineup lineup) {
    state = state.copyWith(competitionLineup: lineup);
    _save();
  }

  void setCompetitionDisplay(CompetitionDisplay display) {
    state = state.copyWith(competitionDisplay: display);
    _save();
  }

  // Settings zurücksetzen
  void resetToDefaults() {
    state =
        const Settings(); // Verwendet Default-Werte aus Settings Konstruktor
    _save();
  }

  /// Setzt nur die Werte eines Bereichs zurück.
  ///
  /// Jeder Einstellungs-Screen hat seine eigene Reset-Zeile, und die darf nur
  /// anfassen, was auf diesem Screen steht — sonst würde die Reset-Zeile der
  /// Wettkampf-Einstellungen die Ampelzeiten mitnehmen.
  void resetSection(SettingsSection section) {
    const defaults = Settings();

    state = switch (section) {
      SettingsSection.general => state.copyWith(
        language: defaults.language,
        fullscreen: defaults.fullscreen,
        soundEnabled: defaults.soundEnabled,
        signalTone: defaults.signalTone,
        volume: defaults.volume,
      ),
      SettingsSection.timer => state.copyWith(
        defaultMode: defaults.defaultMode,
        showMilliseconds: defaults.showMilliseconds,
        timeFormat: defaults.timeFormat,
        alternatingArrows: defaults.alternatingArrows,
        timerScale: defaults.timerScale,
        customPrepTime: defaults.customPrepTime,
        customMainTime: defaults.customMainTime,
      ),
      SettingsSection.competition => state.copyWith(
        // Auch hier, obwohl das Feld beiden Uhren gehört: die Zeile steht auf
        // diesem Schirm, also muss die Reset-Zeile darunter sie auch treffen.
        // Beide Bereiche setzen denselben Default — es kann nichts auseinander
        // laufen.
        timeFormat: defaults.timeFormat,
        competitionDiscipline: defaults.competitionDiscipline,
        competitionEnds: defaults.competitionEnds,
        competitionLineup: defaults.competitionLineup,
        competitionDisplay: defaults.competitionDisplay,
      ),
    };
    _save();
  }
}

// Settings Provider - Hauptprovider für Settings
final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  () => SettingsNotifier(),
);

// Convenience Provider für häufige Settings-Zugriffe
final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).soundEnabled;
});

final volumeProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).volume;
});

final signalToneProvider = Provider<SignalTone>((ref) {
  return ref.watch(settingsProvider).signalTone;
});

final defaultTimerModeProvider = Provider<TimerMode>((ref) {
  return ref.watch(settingsProvider).defaultMode;
});

final showMillisecondsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).showMilliseconds;
});

final timeFormatProvider = Provider<TimeFormat>((ref) {
  return ref.watch(settingsProvider).timeFormat;
});

final languageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(settingsProvider).language;
});

final fullscreenProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).fullscreen;
});

final customPrepTimeProvider = Provider<Duration>((ref) {
  return ref.watch(settingsProvider).customPrepTime;
});

final customMainTimeProvider = Provider<Duration>((ref) {
  return ref.watch(settingsProvider).customMainTime;
});

final alternatingArrowsProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).alternatingArrows;
});

final timerScaleProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).timerScale;
});

final competitionDisciplineProvider = Provider<CompetitionDiscipline>((ref) {
  return ref.watch(settingsProvider).competitionDiscipline;
});

final competitionEndsProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).competitionEnds;
});

final competitionLineupProvider = Provider<CompetitionLineup>((ref) {
  return ref.watch(settingsProvider).competitionLineup;
});

final competitionDisplayProvider = Provider<CompetitionDisplay>((ref) {
  return ref.watch(settingsProvider).competitionDisplay;
});
