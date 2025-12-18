import '../../models/timer_state.dart';

class TimerTexts {
  // Phase Texte
  static const Map<TimerPhase, String> _phaseTexts = {
    TimerPhase.idle: 'Bereit',
    TimerPhase.preparation: 'Vorbereitung',
    TimerPhase.active: 'Aktiv',
    TimerPhase.ended: 'Beendet',
  };

  // Timer-Mode Texte
  static const Map<TimerMode, String> _modeTexts = {
    TimerMode.indoor: 'Indoor Timer',
    TimerMode.outdoor: 'Outdoor Timer',
    TimerMode.custom: 'Benutzerdefiniert',
    TimerMode.alternating: '20s Wechsel-Timer',
    TimerMode.trafficLight: 'Reine Ampel',
  };

  // Basis-Texte
  static String getPhaseText(TimerPhase phase) {
    return _phaseTexts[phase] ?? 'Unbekannt';
  }

  static String getModeText(TimerMode mode) {
    return _modeTexts[mode] ?? 'Unbekannt';
  }

  // Erweiterte/Kombinierte Texte basierend auf State
  static String getPhaseTextEnhanced(TimerState state) {
    final baseText = getPhaseText(state.phase);

    if (state.isInWarningPeriod) {
      return baseText;
    }

    if (state.isPaused) {
      return '$baseText (Pausiert)';
    }

    return baseText;
  }

  // UI-Labels für Buttons/Menu
  static const String startButton = 'Start';
  static const String pauseButton = 'Pause';
  static const String resumeButton = 'Fortsetzen';
  static const String resetButton = 'Reset';
  static const String menuButton = 'Menü';
  static const String settingsButton = 'Einstellungen';
  static const String backButton = 'Zurück';

  // Keyboard Hints
  static const String keyboardHints =
      '[Space] Start/Pause  [Enter] Reset  [Esc] Menü';

  // Time formatting helpers
  static String formatTime(Duration duration, {bool showMilliseconds = false}) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (showMilliseconds) {
      final milliseconds = (duration.inMilliseconds % 1000) ~/ 100;
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$milliseconds';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
