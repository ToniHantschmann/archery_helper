import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../models/timer_state.dart';

// Settings Business Logic Notifier
class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings());

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  void setDefaultMode(TimerMode mode) {
    state = state.copyWith(defaultMode: mode);
  }

  void toggleShowMilliseconds() {
    state = state.copyWith(showMilliseconds: !state.showMilliseconds);
  }

  void setCustomPrepTime(Duration duration) {
    state = state.copyWith(customPrepTime: duration);
  }

  void setCustomMainTime(Duration duration) {
    state = state.copyWith(customMainTime: duration);
  }

  void toggleAutoStart() {
    state = state.copyWith(autoStart: !state.autoStart);
  }

  // Alle Settings auf einmal aktualisieren
  void updateSettings(Settings newSettings) {
    state = newSettings;
    // TODO: Später SharedPreferences hinzufügen für Persistierung
  }

  // Settings zurücksetzen
  void resetToDefaults() {
    state =
        const Settings(); // Verwendet Default-Werte aus Settings Konstruktor
  }
}

// Settings Provider - Hauptprovider für Settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
  (ref) => SettingsNotifier(),
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
