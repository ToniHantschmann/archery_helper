import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keyboard_config.dart';

class KeyboardConfigRepository {
  static const String _configKey = 'keyboard_config';
  static const String _versionKey = 'keyboard_config_version';

  /// Stand der Standardbelegung. Hochzählen, wenn eine *bestehende* Belegung
  /// eine andere Taste bekommt.
  ///
  /// Neue Aktionen ergänzt [KeyboardConfig.fromJson] von selbst, eine
  /// umgelegte kann es nicht: gespeichert steht dort noch die alte Taste, und
  /// die zu überschreiben wäre genau das, was eine eigene Belegung schützen
  /// soll. Solange es keine Oberfläche zum Umlegen gibt, ist jede gespeicherte
  /// Konfiguration ohnehin nur ein älterer Satz Standardwerte — der wird
  /// deshalb verworfen statt vermischt.
  static const int _currentVersion = 2;

  /// load keyboard config from shared preferences
  Future<KeyboardConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_configKey);

    if (jsonString == null || prefs.getInt(_versionKey) != _currentVersion) {
      return KeyboardConfig.defaults();
    }

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
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonString);
    await prefs.setInt(_versionKey, _currentVersion);
  }

  /// removes config
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_versionKey);
  }
}
