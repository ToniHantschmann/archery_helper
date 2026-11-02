import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keyboard_config.dart';

class KeyboardConfigRepository {
  /// Gespeichert werden nur die Zusatztasten. Die Standardbelegung steht im
  /// Code, deshalb braucht es keinen Versionszähler mehr: eine geänderte
  /// Standardtaste gilt beim nächsten Start einfach, und eine gespeicherte
  /// Zusatztaste, die inzwischen Standard ist, fällt beim Laden weg (siehe
  /// [KeyboardConfig.fromJson]).
  static const String _extraKeysKey = 'keyboard_extra_keys';

  /// Die Schlüssel der früheren, vollständig gespeicherten Belegung. Darin
  /// standen nur ältere Standardwerte — es gab keine Oberfläche zum Umlegen —,
  /// also wird nichts davon übernommen, nur beim Speichern aufgeräumt.
  static const List<String> _legacyKeys = [
    'keyboard_config',
    'keyboard_config_version',
  ];

  /// load keyboard config from shared preferences
  Future<KeyboardConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_extraKeysKey);

    if (jsonString == null) return KeyboardConfig.defaults();

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return KeyboardConfig.fromJson(json);
    } catch (e) {
      return KeyboardConfig.defaults();
    }
  }

  /// saves keyboard config to shared preferences
  Future<void> saveConfig(KeyboardConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_extraKeysKey, jsonEncode(config.toJson()));
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
  }

  /// removes config
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_extraKeysKey);
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
  }
}
