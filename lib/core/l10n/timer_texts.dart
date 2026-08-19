import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/settings.dart';
import '../../models/timer_state.dart';
import 'app_language.dart';
import '../../providers/settings_provider.dart';

/// Localized texts for the timer screen and timer-related UI
class TimerTexts {
  final AppLanguage _language;

  const TimerTexts(this._language);

  // ===== PHASE TEXTS =====

  static const _idle = LocalizedText(de: 'Bereit', en: 'Ready');

  static const _preparation = LocalizedText(
    de: 'Vorbereitung',
    en: 'Preparation',
  );

  static const _active = LocalizedText(de: 'Aktiv', en: 'Active');

  static const _ended = LocalizedText(de: 'Beendet', en: 'Ended');

  static const _paused = LocalizedText(de: 'Pausiert', en: 'Paused');

  // ===== SIGNAL TEXTS (Ampel-Modus) =====
  //
  // Im Ampel-Modus ersetzt eines dieser beiden Wörter die ganze Anzeige, es
  // steht also formatfüllend im Tunnel. Beide sind kurz gehalten, damit die
  // FittedBox sie gleich groß skaliert — ein langes Wort auf einer Seite
  // würde den Wechsel auch als Größensprung lesen lassen.

  static const _signalShoot = LocalizedText(de: 'Schießen', en: 'Shoot');

  static const _signalStop = LocalizedText(de: 'Stopp', en: 'Stop');

  // ===== WECHSEL-MODUS =====
  //
  // Das Phasenwort benennt hier den Schützen, nicht die Phase: aus der Distanz
  // ist "wer schießt jetzt" die einzige Frage, die der Bildschirm beantworten
  // muss. Die Buchstaben A und B stehen sprachneutral in [Archer.letter].

  static const _archer = LocalizedText(de: 'Schütze', en: 'Archer');

  static const _arrow = LocalizedText(de: 'Pfeil', en: 'Arrow');

  // ===== TIMER MODE TEXTS =====

  static const _indoor = LocalizedText(de: 'Indoor Timer', en: 'Indoor Timer');

  static const _outdoor = LocalizedText(
    de: 'Outdoor Timer',
    en: 'Outdoor Timer',
  );

  static const _custom = LocalizedText(de: 'Benutzerdefiniert', en: 'Custom');

  static const _alternating = LocalizedText(
    de: '20s Wechsel-Timer',
    en: '20s Alternating Timer',
  );

  static const _trafficLight = LocalizedText(
    de: 'Ampel',
    en: 'Traffic Light Only',
  );

  // ===== BUTTON TEXTS =====

  static const _start = LocalizedText(de: 'Start', en: 'Start');

  static const _pause = LocalizedText(de: 'Pause', en: 'Pause');

  static const _resume = LocalizedText(de: 'Fortsetzen', en: 'Resume');

  static const _reset = LocalizedText(de: 'Reset', en: 'Reset');

  static const _menu = LocalizedText(de: 'Menü', en: 'Menu');

  static const _settings = LocalizedText(de: 'Einstellungen', en: 'Settings');

  static const _back = LocalizedText(de: 'Zurück', en: 'Back');

  static const _previousMode = LocalizedText(de: '◀ Modus', en: '◀ Mode');

  static const _nextMode = LocalizedText(de: 'Modus ▶', en: 'Mode ▶');

  // ===== KEYBOARD HINTS =====

  static const _keyboardHints = LocalizedText(
    de: '[Leertaste] Start/Pause  [Enter] Reset  [Esc] Menü',
    en: '[Space] Start/Pause  [Enter] Reset  [Esc] Menu',
  );

  /// Label printed on the space bar key cap. "Leertaste" is too long for a
  /// cap, so the rail uses the short form.
  static const _keySpace = LocalizedText(de: 'Leer', en: 'Space');

  static const _hintStartNext = LocalizedText(
    de: 'Start / Weiter',
    en: 'Start / next',
  );

  static const _hintPlayPause = LocalizedText(
    de: 'Pause / Weiter',
    en: 'Pause / resume',
  );

  static const _hintToggleSignal = LocalizedText(
    de: 'Umschalten',
    en: 'Switch',
  );

  static const _hintReset = LocalizedText(de: 'Zurücksetzen', en: 'Reset');

  static const _hintMode = LocalizedText(de: 'Modus', en: 'Mode');

  static const _hintSettings = LocalizedText(
    de: 'Einstellungen',
    en: 'Settings',
  );

  static const _hintMenu = LocalizedText(de: 'Menü', en: 'Menu');

  // ===== PUBLIC GETTERS =====

  String get idle => _idle.get(_language);
  String get preparation => _preparation.get(_language);
  String get active => _active.get(_language);
  String get ended => _ended.get(_language);
  String get paused => _paused.get(_language);
  String get signalShoot => _signalShoot.get(_language);
  String get signalStop => _signalStop.get(_language);
  String get archer => _archer.get(_language);
  String get arrow => _arrow.get(_language);

  String get indoor => _indoor.get(_language);
  String get outdoor => _outdoor.get(_language);
  String get custom => _custom.get(_language);
  String get alternating => _alternating.get(_language);
  String get trafficLight => _trafficLight.get(_language);

  String get startButton => _start.get(_language);
  String get pauseButton => _pause.get(_language);
  String get resumeButton => _resume.get(_language);
  String get resetButton => _reset.get(_language);
  String get menuButton => _menu.get(_language);
  String get settingsButton => _settings.get(_language);
  String get backButton => _back.get(_language);
  String get previousModeButton => _previousMode.get(_language);
  String get nextModeButton => _nextMode.get(_language);

  String get keyboardHints => _keyboardHints.get(_language);

  String get keySpaceLabel => _keySpace.get(_language);
  String get hintStartNext => _hintStartNext.get(_language);
  String get hintPlayPause => _hintPlayPause.get(_language);
  String get hintToggleSignal => _hintToggleSignal.get(_language);
  String get hintReset => _hintReset.get(_language);
  String get hintMode => _hintMode.get(_language);
  String get hintSettings => _hintSettings.get(_language);
  String get hintMenu => _hintMenu.get(_language);

  // ===== HELPER METHODS =====

  /// Get phase text based on TimerPhase
  String getPhaseText(TimerPhase phase) {
    switch (phase) {
      case TimerPhase.idle:
        return idle;
      case TimerPhase.preparation:
        return preparation;
      case TimerPhase.active:
        return active;
      case TimerPhase.ended:
        return ended;
    }
  }

  /// Get mode text based on TimerMode
  String getModeText(TimerMode mode) {
    switch (mode) {
      case TimerMode.indoor:
        return indoor;
      case TimerMode.outdoor:
        return outdoor;
      case TimerMode.custom:
        return custom;
      case TimerMode.alternating:
        return alternating;
      case TimerMode.trafficLight:
        return trafficLight;
    }
  }

  /// Zähler für die Statusleiste des Wechselmodus, z.B. "Pfeil 2/3".
  String arrowCounter(int current, int total) => '$arrow $current/$total';

  /// Phasenwort des Wechselmodus, oder `null` wenn es hier keines gibt.
  ///
  /// Nur solange wirklich gewechselt wird: `idle` und `ended` gehören zur
  /// ganzen Passe, nicht zu einem der beiden Schützen, und behalten deshalb
  /// "Bereit" bzw. "Beendet".
  String? _alternatingPhaseText(TimerState state) {
    if (!state.mode.isAlternating || !state.phase.isRunningPhase) return null;

    final base = state.phase == TimerPhase.active ? archer : preparation;
    return '$base ${state.currentArcher.letter}';
  }

  /// Get enhanced phase text that includes paused state
  String getPhaseTextEnhanced(TimerState state) {
    // Im Ampel-Modus ist dieses Wort die gesamte Anzeige, nicht die
    // Beschriftung über einer Uhr — es benennt deshalb die Handlung und nicht
    // die Phase. Pausiert kann der Modus nicht sein.
    if (state.mode.isManual) {
      return state.phase == TimerPhase.active ? signalShoot : signalStop;
    }

    final baseText = _alternatingPhaseText(state) ?? getPhaseText(state.phase);

    if (state.isInWarningPeriod) {
      return baseText;
    }

    if (state.isPaused) {
      return '$baseText ($paused)';
    }

    return baseText;
  }

  /// Format time duration
  ///
  /// [format] entscheidet nur über die Schreibweise ("4:00" oder "240"), nicht
  /// über die Rundung: beide Zweige zeigen dieselbe Sekunde zum selben
  /// Zeitpunkt.
  static String formatTime(
    Duration duration, {
    bool showMilliseconds = false,
    TimeFormat format = TimeFormat.minutesSeconds,
  }) {
    if (showMilliseconds) {
      // Hier wird abgeschnitten, denn die Zehntel werden ja mit angezeigt.
      final milliseconds = (duration.inMilliseconds % 1000) ~/ 100;
      if (format == TimeFormat.seconds) {
        return '${duration.inSeconds}.$milliseconds';
      }

      final seconds = duration.inSeconds % 60;
      return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}'
          '.$milliseconds';
    }

    // Aufgerundet, nicht abgeschnitten: bei 1:59,9 soll noch "2:00" stehen.
    // Sonst würde der Startwert praktisch übersprungen. So steht jede Zahl
    // genau eine Sekunde und "0:00" erscheint erst, wenn die Zeit wirklich um
    // ist. Das Aufrunden definiert zugleich die Kante, auf die TimerNotifier
    // sein nächstes Update plant — wer hier die Rundung ändert, verschiebt den
    // Zeitpunkt des Wechsels mit.
    final totalSeconds = (duration.inMilliseconds / 1000).ceil();
    if (format == TimeFormat.seconds) {
      return '$totalSeconds';
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// ===== PROVIDER =====

/// Provider for localized timer texts based on current language from settings
final timerTextsProvider = Provider<TimerTexts>((ref) {
  final language = ref.watch(
    languageProvider,
  ); // Nutzt jetzt languageProvider aus settings_provider
  return TimerTexts(language);
});
