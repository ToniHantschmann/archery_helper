import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsRepository {
  static const String _settingsKey = "app_settings";

  ///
  Future<Settings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    // use default settings if we cant find settings file
    if (jsonString == null) {
      return const Settings();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Settings.fromJson(json);
    } catch (e) {
      return const Settings();
    }
  }

  /// save settings in sharedPreferences
  Future<void> saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }

  /// removes settings file
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
