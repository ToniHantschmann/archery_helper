import 'package:archery_helper/core/l10n/app_language.dart';

import 'competition_state.dart';
import 'timer_state.dart';

/// Wie die laufende Uhr ihre Zahl schreibt — „4:00" oder „240".
///
/// Betrifft nur die Darstellung, nicht die Rundung: beide Formate zeigen
/// dieselbe Sekunde, sie setzen sie nur anders zusammen.
enum TimeFormat { minutesSeconds, seconds }

class Settings {
  final bool soundEnabled;
  final double volume;
  final TimerMode defaultMode;
  final Duration customPrepTime;
  final Duration customMainTime;
  final bool autoStart;
  final bool showMilliseconds;
  final AppLanguage language;

  /// Ob die Uhr „4:00" oder „240" zeigt. Gilt für Ampel und Wettkampf — es ist
  /// dieselbe Frage an dieselbe Zahl, deshalb gibt es sie nur einmal.
  final TimeFormat timeFormat;

  /// Ob die App das Fenster füllt. Der Tunnelrechner läuft als Kiosk, deshalb
  /// ist Vollbild der Normalfall; F11 und die Zeile in den allgemeinen
  /// Einstellungen schalten dasselbe Feld.
  final bool fullscreen;

  /// Pfeile pro Schütze im Wechselmodus. Eine Passe besteht damit aus
  /// 2 × [alternatingArrows] Passagen.
  final int alternatingArrows;

  /// Wie groß Uhr und Phasenwort der Ampel gezeichnet werden, als Faktor.
  ///
  /// 1.0 heißt „füllt die Fläche exakt" — die Uhr steckt in einer `FittedBox`,
  /// passt sich also von selbst ein, und dieser Faktor verschiebt genau diesen
  /// Einpasspunkt. Größer als 1.0 ist damit ausdrücklich erlaubt und wird an
  /// der Kante der Anzeigefläche beschnitten: die Zeilenbox der Schrift ist
  /// höher als die Ziffern selbst, dieser Rest ist von außen nicht ausrechenbar
  /// und wird deshalb dem Auge im Tunnel überlassen.
  ///
  /// Gilt nur für die Ampel, nicht für den Wettkampf und nicht für die LED-Wand.
  final double timerScale;

  /// Halle oder Freiluft im Wettkampfmodus — bestimmt Pfeilzahl und Schusszeit
  /// einer Passe, siehe [CompetitionDiscipline].
  final CompetitionDiscipline competitionDiscipline;

  /// Wie viele Passen eine Wettkampfrunde hat.
  final int competitionEnds;

  /// Wie die Schützen an der Scheibe aufgeteilt sind.
  final CompetitionLineup competitionLineup;

  /// Auf welchem Schirm der Wettkampf angezeigt wird — Monitor oder LED-Wand.
  final CompetitionDisplay competitionDisplay;

  const Settings({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.defaultMode = TimerMode.indoor,
    this.customPrepTime = const Duration(seconds: 10),
    this.customMainTime = const Duration(seconds: 120),
    this.autoStart = false,
    this.showMilliseconds = false,
    this.language = AppLanguage.german,
    this.timeFormat = TimeFormat.minutesSeconds,
    this.fullscreen = true,
    this.alternatingArrows = 3,
    this.timerScale = 1.0,
    this.competitionDiscipline = CompetitionDiscipline.indoor,
    this.competitionEnds = 20,
    this.competitionLineup = CompetitionLineup.abcd,
    this.competitionDisplay = CompetitionDisplay.standard,
  });

  /// Grenzen für [alternatingArrows]. Drei Pfeile sind der Wettkampf-Fall,
  /// alles darüber ist Training.
  static const minAlternatingArrows = 1;
  static const maxAlternatingArrows = 6;

  /// Grenzen für [competitionEnds]. 20 Passen sind die Hallenrunde, 12 die
  /// Freiluftrunde; darunter liegt jedes kürzere Vereinsformat.
  static const minCompetitionEnds = 1;
  static const maxCompetitionEnds = 30;

  /// Grenzen und Schrittweite für [timerScale], in Prozent gerechnet: mit
  /// Kommazahlen zu schrittweise addieren würde sich aufaddierende Rundungs-
  /// fehler einfangen, ganze Prozente treffen die 100 immer.
  static const minTimerScale = 0.7;
  static const maxTimerScale = 3.0;
  static const timerScaleStepPercent = 5;

  Settings copyWith({
    bool? soundEnabled,
    double? volume,
    TimerMode? defaultMode,
    Duration? customPrepTime,
    Duration? customMainTime,
    bool? autoStart,
    bool? showMilliseconds,
    AppLanguage? language,
    TimeFormat? timeFormat,
    bool? fullscreen,
    int? alternatingArrows,
    double? timerScale,
    CompetitionDiscipline? competitionDiscipline,
    int? competitionEnds,
    CompetitionLineup? competitionLineup,
    CompetitionDisplay? competitionDisplay,
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
      timeFormat: timeFormat ?? this.timeFormat,
      fullscreen: fullscreen ?? this.fullscreen,
      alternatingArrows: alternatingArrows ?? this.alternatingArrows,
      timerScale: timerScale ?? this.timerScale,
      competitionDiscipline:
          competitionDiscipline ?? this.competitionDiscipline,
      competitionEnds: competitionEnds ?? this.competitionEnds,
      competitionLineup: competitionLineup ?? this.competitionLineup,
      competitionDisplay: competitionDisplay ?? this.competitionDisplay,
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
      "timeFormat": timeFormat.index,
      "fullscreen": fullscreen,
      "alternatingArrows": alternatingArrows,
      "timerScale": timerScale,
      "competitionDiscipline": competitionDiscipline.index,
      "competitionEnds": competitionEnds,
      "competitionLineup": competitionLineup.index,
      "competitionDisplay": competitionDisplay.index,
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
      timeFormat: _parseEnum(
        TimeFormat.values,
        json['timeFormat'] as int?,
        TimeFormat.minutesSeconds,
      ),
      fullscreen: json['fullscreen'] as bool? ?? true,
      alternatingArrows: _parseArrows(json['alternatingArrows'] as int?),
      timerScale: _parseScale(json['timerScale']),
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
      competitionDisplay: _parseEnum(
        CompetitionDisplay.values,
        json['competitionDisplay'] as int?,
        CompetitionDisplay.standard,
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

  /// Helper: keep the display scale inside its range (with fallback)
  ///
  /// Nimmt bewusst `dynamic` statt `double?`: ein glatter Wert landet als `int`
  /// im JSON, und ein `as double?` würde daran mit einem Cast-Fehler die
  /// gesamte gespeicherte Konfiguration verwerfen.
  static double _parseScale(Object? scale) {
    if (scale is! num) return 1.0;
    return scale.toDouble().clamp(minTimerScale, maxTimerScale);
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
