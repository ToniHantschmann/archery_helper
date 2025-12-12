import 'timer_state.dart';

class Settings {
  final bool soundEnabled;
  final double volume;
  final TimerMode defaultMode;
  final Duration customPrepTime;
  final Duration customMainTime;
  final bool autoStart;
  final bool showMilliseconds;

  const Settings({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.defaultMode = TimerMode.indoor,
    this.customPrepTime = const Duration(seconds: 10),
    this.customMainTime = const Duration(seconds: 120),
    this.autoStart = false,
    this.showMilliseconds = false,
  });

  Settings copyWith({
    bool? soundEnabled,
    double? volume,
    TimerMode? defaultMode,
    Duration? customPrepTime,
    Duration? customMainTime,
    bool? autoStart,
    bool? showMilliseconds,
  }) {
    return Settings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      defaultMode: defaultMode ?? this.defaultMode,
      customPrepTime: customPrepTime ?? this.customPrepTime,
      customMainTime: customMainTime ?? this.customMainTime,
      autoStart: autoStart ?? this.autoStart,
      showMilliseconds: showMilliseconds ?? this.showMilliseconds,
    );
  }
}
