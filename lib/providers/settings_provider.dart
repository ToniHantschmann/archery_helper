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

  @override
  Settings build() {
    _repository = ref.watch(settingsRepositoryProvider);
    // initially start with default settings and load real settings later with loadSettings()
    return const Settings();
  }

  /// load settings from repository
  Future<void> loadSettings() async {
    state = await _repository.loadSettings();
  }

  /// save current state
  Future<void> _save() async {
    await _repository.saveSettings(state);
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
