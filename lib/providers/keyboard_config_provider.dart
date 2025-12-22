import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/keyboard_config.dart';

/// Provider für die Keyboard-Konfiguration
class KeyboardConfigNotifier extends Notifier<KeyboardConfig> {
  @override
  KeyboardConfig build() {
    return KeyboardConfig.defaults();
  }

  /// Setzt eine neue Tastenbelegung
  void setKeyBinding(LogicalKeyboardKey key, AppAction action) {
    state = state.addKeyBinding(key, action);
    // TODO: Später in SharedPreferences speichern
  }

  /// Entfernt eine Tastenbelegung
  void removeKeyBinding(LogicalKeyboardKey key) {
    state = state.removeKeyBinding(key);
    // TODO: Später in SharedPreferences speichern
  }

  /// Setzt die Tastenbelegung auf Standard zurück
  void resetToDefaults() {
    state = KeyboardConfig.defaults();
    // TODO: Später aus SharedPreferences löschen
  }

  /// Lädt die gespeicherte Konfiguration
  Future<void> loadConfig() async {
    // TODO: Aus SharedPreferences laden
    // Für jetzt verwenden wir die Defaults
  }
}

/// Haupt-Provider für Keyboard-Konfiguration
final keyboardConfigProvider =
    NotifierProvider<KeyboardConfigNotifier, KeyboardConfig>(
      () => KeyboardConfigNotifier(),
    );

/// Convenience Provider: Gibt die Aktion für eine Taste zurück
final keyActionProvider = Provider.family<AppAction?, LogicalKeyboardKey>((
  ref,
  key,
) {
  return ref.watch(keyboardConfigProvider).getAction(key);
});
