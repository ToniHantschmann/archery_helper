import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keyboard_config.dart';

class KeyboardConfigRepository {
  static const String _configKey = 'keyboard_config';

  /// Lädt Keyboard-Konfiguration aus SharedPreferences
  Future<KeyboardConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_configKey);

    if (jsonString == null) {
      return KeyboardConfig.defaults();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return KeyboardConfig.fromJson(json);
    } catch (e) {
      // Bei Fehler: Defaults zurückgeben
      return KeyboardConfig.defaults();
    }
  }

  /// Speichert Keyboard-Konfiguration in SharedPreferences
  Future<void> saveConfig(KeyboardConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonString);
  }

  /// Löscht gespeicherte Konfiguration
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
