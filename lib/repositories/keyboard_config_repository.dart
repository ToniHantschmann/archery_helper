import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/keyboard_config.dart';

class KeyboardConfigRepository {
  static const String _configKey = 'keyboard_config';

  /// load keyboard config from shared preferences
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
      return KeyboardConfig.defaults();
    }
  }

  /// saves keyboard config to shared preferences
  Future<void> saveConfig(KeyboardConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonString);
  }

  /// removes config
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
