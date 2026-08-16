import 'dart:async';

import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
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

  void setDefaultMode(TimerMode mode) {
    state = state.copyWith(defaultMode: mode);
    _save();
  }

  void toggleShowMilliseconds() {
    state = state.copyWith(showMilliseconds: !state.showMilliseconds);
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

  void toggleAutoStart() {
    state = state.copyWith(autoStart: !state.autoStart);
    _save();
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    _save();
  }

  // Settings zurücksetzen
  void resetToDefaults() {
    state =
        const Settings(); // Verwendet Default-Werte aus Settings Konstruktor
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

final defaultTimerModeProvider = Provider<TimerMode>((ref) {
  return ref.watch(settingsProvider).defaultMode;
});

final showMillisecondsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).showMilliseconds;
});

final autoStartProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).autoStart;
});

final languageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(settingsProvider).language;
});

final customPrepTimeProvider = Provider<Duration>((ref) {
  return ref.watch(settingsProvider).customPrepTime;
});

final customMainTimeProvider = Provider<Duration>((ref) {
  return ref.watch(settingsProvider).customMainTime;
});
