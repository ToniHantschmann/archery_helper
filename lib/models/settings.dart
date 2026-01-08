import 'package:archery_helper/core/l10n/app_language.dart';

import 'timer_state.dart';

class Settings {
  final bool soundEnabled;
  final double volume;
  final TimerMode defaultMode;
  final Duration customPrepTime;
  final Duration customMainTime;
  final bool autoStart;
  final bool showMilliseconds;
  final AppLanguage language;

  const Settings({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.defaultMode = TimerMode.indoor,
    this.customPrepTime = const Duration(seconds: 10),
    this.customMainTime = const Duration(seconds: 120),
    this.autoStart = false,
    this.showMilliseconds = false,
    this.language = AppLanguage.german,
  });

  Settings copyWith({
    bool? soundEnabled,
    double? volume,
    TimerMode? defaultMode,
    Duration? customPrepTime,
    Duration? customMainTime,
    bool? autoStart,
    bool? showMilliseconds,
    AppLanguage? language,
  }) {
    return Settings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      defaultMode: defaultMode ?? this.defaultMode,
      customPrepTime: customPrepTime ?? this.customPrepTime,
      customMainTime: customMainTime ?? this.customMainTime,
      autoStart: autoStart ?? this.autoStart,
      showMilliseconds: showMilliseconds ?? this.showMilliseconds,
      language: language ?? this.language,
    );
  }

  /// Serialization: convert settings to map
  Map<String, dynamic> toJson() {
    return {
      "soundEnabled": soundEnabled,
      "volume": volume,
      "defaultMode": defaultMode.index,
      "customPrepTime": customPrepTime.inSeconds,
      "customMainTime": customMainTime.inSeconds,
      "autoStart": autoStart,
      "showMilliseconds": showMilliseconds,
      "language": language,
    };
  }

  /// create settings from json
  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      volume: json['volume'] as double? ?? 0.8,
      defaultMode: _parseTimerMode(json['defaultMode'] as int?),
      customPrepTime: Duration(seconds: json['customPrepTime'] as int? ?? 10),
      customMainTime: Duration(seconds: json['customMainTime'] as int? ?? 120),
      autoStart: json['autoStart'] as bool? ?? false,
      showMilliseconds: json['showMilliseconds'] as bool? ?? false,
      language: _parseLanguage(json['language'] as String?),
    );
  }

  /// Helper: convert int to timerMode (with fallback)
  static TimerMode _parseTimerMode(int? index) {
    if (index == null || index < 0 || index >= TimerMode.values.length) {
      return TimerMode.indoor;
    }
    return TimerMode.values[index];
  }

  /// Helper: convert string to AppLanguage
  static AppLanguage _parseLanguage(String? code) {
    if (code == null) {
      return AppLanguage.german;
    }
    return AppLanguage.fromCode(code);
  }
}
