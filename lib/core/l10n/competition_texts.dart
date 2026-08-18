import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/competition_state.dart';
import '../../models/timer_state.dart';
import '../../providers/settings_provider.dart';
import 'app_language.dart';

/// Localized texts for the competition screen.
///
/// Eigene Klasse pro Screen, wie überall in `lib/core/l10n/` — die Ampel und der
/// Wettkampf sagen verschiedene Dinge, auch wenn sie gleich aussehen.
class CompetitionTexts {
  final AppLanguage _language;

  const CompetitionTexts(this._language);

  // ===== PHASENWÖRTER =====

  static const _ready = LocalizedText(de: 'Bereit', en: 'Ready');

  /// Zwischen zwei Passen. Sagt, was gerade passiert (die Schützen sind an der
  /// Scheibe), und dass die Uhr auf den Schießleiter wartet.
  static const _collectArrows = LocalizedText(
    de: 'Pfeile holen',
    en: 'Collect Arrows',
  );

  static const _preparation = LocalizedText(
    de: 'Vorbereitung',
    en: 'Preparation',
  );

  /// Die Vorbereitungszeit beim Gruppenwechsel. Dieselbe rote Phase wie oben,
  /// aber eine andere Ansage: die eine Gruppe geht weg, die andere kommt.
  static const _changeover = LocalizedText(de: 'Wechsel', en: 'Change');

  static const _shooting = LocalizedText(de: 'Schießen', en: 'Shooting');

  static const _finished = LocalizedText(de: 'Runde zu Ende', en: 'Round Over');

  static const _paused = LocalizedText(de: 'Pause', en: 'Paused');

  // ===== ANZEIGE =====

  static const _end = LocalizedText(de: 'Passe', en: 'End');

  static const _screenTitle = LocalizedText(de: 'Wettkampf', en: 'Competition');

  // ===== HINTS =====

  static const _hintNext = LocalizedText(de: 'Weiter', en: 'Next');

  static const _hintStart = LocalizedText(de: 'Start', en: 'Start');

  static const _hintPause = LocalizedText(de: 'Pause', en: 'Pause');

  static const _hintResume = LocalizedText(de: 'Fortsetzen', en: 'Resume');

  static const _hintReset = LocalizedText(de: 'Zurücksetzen', en: 'Reset');

  static const _hintSettings = LocalizedText(
    de: 'Einstellungen',
    en: 'Settings',
  );

  static const _hintMenu = LocalizedText(de: 'Menü', en: 'Menu');

  static const _hintSelect = LocalizedText(de: 'Auswählen', en: 'Select');

  // ===== PUBLIC =====

  String get screenTitle => _screenTitle.get(_language);

  /// Beschriftung der Weiter-Taste. Steht die Runde, ist sie das Startsignal —
  /// „Weiter" wäre dort die falsche Ansage.
  String nextLabel(CompetitionState state) =>
      state.canStart ? _hintStart.get(_language) : _hintNext.get(_language);

  String get hintReset => _hintReset.get(_language);
  String get hintSettings => _hintSettings.get(_language);
  String get hintMenu => _hintMenu.get(_language);
  String get hintSelect => _hintSelect.get(_language);

  /// Beschriftung der Start/Pause-Taste, passend zum Stand der Runde.
  String toggleLabel(CompetitionState state) {
    if (state.isPaused) return _hintResume.get(_language);
    if (state.canStart || state.isFinished) return _hintStart.get(_language);
    return _hintPause.get(_language);
  }

  /// Das Wort über der Uhr.
  String phaseText(CompetitionState state) {
    if (state.isPaused) return _paused.get(_language);

    switch (state.phase) {
      case TimerPhase.idle:
        return (state.isWaitingBetweenEnds ? _collectArrows : _ready)
            .get(_language);
      case TimerPhase.preparation:
        return (state.isChangeover ? _changeover : _preparation).get(_language);
      case TimerPhase.active:
        return _shooting.get(_language);
      case TimerPhase.ended:
        return _finished.get(_language);
    }
  }

  /// Der Passenzähler: „Passe 3/20".
  String endCounter(int current, int total) =>
      '${_end.get(_language)} $current/$total';
}

final competitionTextsProvider = Provider<CompetitionTexts>((ref) {
  return CompetitionTexts(ref.watch(languageProvider));
});
