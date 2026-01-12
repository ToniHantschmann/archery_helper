import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // ===== PUBLIC GETTERS =====

  String get idle => _idle.get(_language);
  String get preparation => _preparation.get(_language);
  String get active => _active.get(_language);
  String get ended => _ended.get(_language);
  String get paused => _paused.get(_language);

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

  /// Get enhanced phase text that includes paused state
  String getPhaseTextEnhanced(TimerState state) {
    final baseText = getPhaseText(state.phase);

    if (state.isInWarningPeriod) {
      return baseText;
    }

    if (state.isPaused) {
      return '$baseText (${paused})';
    }

    return baseText;
  }

  /// Format time duration
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

// ===== PROVIDER =====

/// Provider for localized timer texts based on current language from settings
final timerTextsProvider = Provider<TimerTexts>((ref) {
  final language = ref.watch(
    languageProvider,
  ); // Nutzt jetzt languageProvider aus settings_provider
  return TimerTexts(language);
});
