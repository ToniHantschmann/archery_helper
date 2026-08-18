import 'package:archery_helper/core/l10n/app_language.dart';

import 'competition_state.dart';
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

  /// Pfeile pro Schütze im Wechselmodus. Eine Passe besteht damit aus
  /// 2 × [alternatingArrows] Passagen.
  final int alternatingArrows;

  /// Halle oder Freiluft im Wettkampfmodus — bestimmt Pfeilzahl und Schusszeit
  /// einer Passe, siehe [CompetitionDiscipline].
  final CompetitionDiscipline competitionDiscipline;

  /// Wie viele Passen eine Wettkampfrunde hat.
  final int competitionEnds;

  /// Wie die Schützen an der Scheibe aufgeteilt sind.
  final CompetitionLineup competitionLineup;

  const Settings({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.defaultMode = TimerMode.indoor,
    this.customPrepTime = const Duration(seconds: 10),
    this.customMainTime = const Duration(seconds: 120),
    this.autoStart = false,
    this.showMilliseconds = false,
    this.language = AppLanguage.german,
    this.alternatingArrows = 3,
    this.competitionDiscipline = CompetitionDiscipline.indoor,
    this.competitionEnds = 20,
    this.competitionLineup = CompetitionLineup.abcd,
  });

  /// Grenzen für [alternatingArrows]. Drei Pfeile sind der Wettkampf-Fall,
  /// alles darüber ist Training.
  static const minAlternatingArrows = 1;
  static const maxAlternatingArrows = 6;

  /// Grenzen für [competitionEnds]. 20 Passen sind die Hallenrunde, 12 die
  /// Freiluftrunde; darunter liegt jedes kürzere Vereinsformat.
  static const minCompetitionEnds = 1;
  static const maxCompetitionEnds = 30;

  Settings copyWith({
    bool? soundEnabled,
    double? volume,
    TimerMode? defaultMode,
    Duration? customPrepTime,
    Duration? customMainTime,
    bool? autoStart,
    bool? showMilliseconds,
    AppLanguage? language,
    int? alternatingArrows,
    CompetitionDiscipline? competitionDiscipline,
    int? competitionEnds,
    CompetitionLineup? competitionLineup,
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
      alternatingArrows: alternatingArrows ?? this.alternatingArrows,
      competitionDiscipline:
          competitionDiscipline ?? this.competitionDiscipline,
      competitionEnds: competitionEnds ?? this.competitionEnds,
      competitionLineup: competitionLineup ?? this.competitionLineup,
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
      "language": language.code,
      "alternatingArrows": alternatingArrows,
      "competitionDiscipline": competitionDiscipline.index,
      "competitionEnds": competitionEnds,
      "competitionLineup": competitionLineup.index,
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
      alternatingArrows: _parseArrows(json['alternatingArrows'] as int?),
      competitionDiscipline: _parseEnum(
        CompetitionDiscipline.values,
        json['competitionDiscipline'] as int?,
        CompetitionDiscipline.indoor,
      ),
      competitionEnds: _parseEnds(json['competitionEnds'] as int?),
      competitionLineup: _parseEnum(
        CompetitionLineup.values,
        json['competitionLineup'] as int?,
        CompetitionLineup.abcd,
      ),
    );
  }

  /// Helper: convert int to timerMode (with fallback)
  static TimerMode _parseTimerMode(int? index) {
    if (index == null || index < 0 || index >= TimerMode.values.length) {
      return TimerMode.indoor;
    }
    return TimerMode.values[index];
  }

  /// Helper: keep the arrow count inside its range (with fallback)
  static int _parseArrows(int? arrows) {
    if (arrows == null) return 3;
    return arrows.clamp(minAlternatingArrows, maxAlternatingArrows);
  }

  /// Helper: keep the end count inside its range (with fallback)
  static int _parseEnds(int? ends) {
    if (ends == null) return const Settings().competitionEnds;
    return ends.clamp(minCompetitionEnds, maxCompetitionEnds);
  }

  /// Helper: convert a stored index back to an enum value (with fallback)
  static T _parseEnum<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  /// Helper: convert string to AppLanguage
  static AppLanguage _parseLanguage(String? code) {
    if (code == null) {
      return AppLanguage.german;
    }
    return AppLanguage.fromCode(code);
  }
}
