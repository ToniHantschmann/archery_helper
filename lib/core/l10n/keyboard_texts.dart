import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/keyboard_config.dart';
import '../../providers/settings_provider.dart';
import 'app_language.dart';

/// Localized texts for the key binding screen.
class KeyboardTexts {
  final AppLanguage _language;

  const KeyboardTexts(this._language);

  // ===== SCREEN =====

  static const _title = LocalizedText(de: 'Tastenbelegung', en: 'Key Bindings');

  static const _intro = LocalizedText(
    de:
        'Die Standardtasten sind fest. Zusatztasten — etwa auf einem '
        'Ziffernblock — lösen dieselbe Aktion aus.',
    en:
        'The default keys are fixed. Extra keys — on a numeric keypad, say — '
        'trigger the same action.',
  );

  // ===== SECTIONS =====
  // Entlang der Gruppen im AppAction-Enum.

  static const _clockSection = LocalizedText(de: 'Uhr', en: 'Clock');
  static const _modeSection = LocalizedText(de: 'Modus', en: 'Mode');
  static const _screenSection = LocalizedText(de: 'Screens', en: 'Screens');
  static const _navigationSection = LocalizedText(
    de: 'Navigation',
    en: 'Navigation',
  );

  // ===== ACTIONS =====

  static const _toggleTimer = LocalizedText(
    de: 'Start / Pause',
    en: 'Start / pause',
  );
  static const _resetTimer = LocalizedText(de: 'Zurücksetzen', en: 'Reset');
  static const _skipTimer = LocalizedText(
    de: 'Phase überspringen',
    en: 'Skip phase',
  );
  static const _next = LocalizedText(de: 'Start / Weiter', en: 'Start / next');
  static const _previous = LocalizedText(
    de: 'Eine Position zurück',
    en: 'One position back',
  );
  static const _forward = LocalizedText(
    de: 'Eine Position vor',
    en: 'One position ahead',
  );
  static const _toggleClock = LocalizedText(
    de: 'Uhrzeit anzeigen',
    en: 'Show the time of day',
  );
  static const _toggleCountdown = LocalizedText(
    de: 'Countdown bis zum Start',
    en: 'Countdown to the start',
  );
  static const _nextMode = LocalizedText(de: 'Nächster Modus', en: 'Next mode');
  static const _previousMode = LocalizedText(
    de: 'Vorheriger Modus',
    en: 'Previous mode',
  );
  static const _toggleSettings = LocalizedText(
    de: 'Einstellungen',
    en: 'Settings',
  );
  static const _back = LocalizedText(de: 'Zurück', en: 'Back');
  static const _confirm = LocalizedText(de: 'Bestätigen', en: 'Confirm');
  static const _toggleFullscreen = LocalizedText(
    de: 'Vollbild',
    en: 'Fullscreen',
  );
  static const _navigateUp = LocalizedText(de: 'Hoch', en: 'Up');
  static const _navigateDown = LocalizedText(de: 'Runter', en: 'Down');
  static const _navigateLeft = LocalizedText(
    de: 'Links / Wert verringern',
    en: 'Left / decrease value',
  );
  static const _navigateRight = LocalizedText(
    de: 'Rechts / Wert erhöhen',
    en: 'Right / increase value',
  );

  // ===== CAPTURE =====

  static const _pressKey = LocalizedText(
    de: 'Taste drücken …',
    en: 'Press a key …',
  );

  static const _keySpace = LocalizedText(de: 'Leer', en: 'Space');

  // ===== HINT RAIL =====

  static const _hintSelect = LocalizedText(de: 'Auswählen', en: 'Select');
  static const _hintAdd = LocalizedText(de: 'Taste hinzufügen', en: 'Add key');
  static const _hintRemove = LocalizedText(de: 'Entfernen', en: 'Remove');
  static const _hintBack = LocalizedText(de: 'Zurück', en: 'Back');
  static const _hintCapture = LocalizedText(
    de: 'Neue Taste drücken',
    en: 'Press the new key',
  );
  static const _hintCancel = LocalizedText(de: 'Abbrechen', en: 'Cancel');

  // ===== RESET =====

  static const _reset = LocalizedText(
    de: 'Alle Zusatztasten entfernen',
    en: 'Remove all extra keys',
  );
  static const _resetTitle = LocalizedText(
    de: 'Zusatztasten entfernen',
    en: 'Remove extra keys',
  );
  static const _resetContent = LocalizedText(
    de:
        'Alle Zusatztasten werden entfernt. Die Standardtasten bleiben wie '
        'sie sind.',
    en: 'All extra keys are removed. The default keys stay as they are.',
  );
  static const _resetConfirm = LocalizedText(de: 'Entfernen', en: 'Remove');
  static const _resetCancel = LocalizedText(de: 'Abbrechen', en: 'Cancel');

  String get title => _title.get(_language);
  String get intro => _intro.get(_language);
  String get clockSection => _clockSection.get(_language);
  String get modeSection => _modeSection.get(_language);
  String get screenSection => _screenSection.get(_language);
  String get navigationSection => _navigationSection.get(_language);
  String get pressKey => _pressKey.get(_language);
  String get hintSelect => _hintSelect.get(_language);
  String get hintAdd => _hintAdd.get(_language);
  String get hintRemove => _hintRemove.get(_language);
  String get hintBack => _hintBack.get(_language);
  String get hintCapture => _hintCapture.get(_language);
  String get hintCancel => _hintCancel.get(_language);
  String get reset => _reset.get(_language);
  String get resetTitle => _resetTitle.get(_language);
  String get resetContent => _resetContent.get(_language);
  String get resetConfirm => _resetConfirm.get(_language);
  String get resetCancel => _resetCancel.get(_language);

  /// Wie eine Taste auf ihrer Kappe heißt. Die Leertaste ist die eine, deren
  /// Name übersetzt wird — und „Leertaste" passte auf keine Kappe.
  String keyName(LogicalKeyboardKey key) => key == LogicalKeyboardKey.space
      ? _keySpace.get(_language)
      : KeyboardConfig.getKeyName(key);

  String actionName(AppAction action) {
    final text = switch (action) {
      AppAction.toggleTimer => _toggleTimer,
      AppAction.resetTimer => _resetTimer,
      AppAction.skipTimer => _skipTimer,
      AppAction.next => _next,
      AppAction.previous => _previous,
      AppAction.forward => _forward,
      AppAction.toggleClock => _toggleClock,
      AppAction.toggleCountdown => _toggleCountdown,
      AppAction.nextMode => _nextMode,
      AppAction.previousMode => _previousMode,
      AppAction.toggleSettings => _toggleSettings,
      AppAction.back => _back,
      AppAction.confirm => _confirm,
      AppAction.toggleFullscreen => _toggleFullscreen,
      AppAction.navigateUp => _navigateUp,
      AppAction.navigateDown => _navigateDown,
      AppAction.navigateLeft => _navigateLeft,
      AppAction.navigateRight => _navigateRight,
    };
    return text.get(_language);
  }

  /// Was die Zeile nach einer Aufnahme dazusagt — `null`, wenn die Kappe, die
  /// jetzt dasteht, schon alles sagt.
  String? notice(KeyAssignment assignment) {
    final key = keyName(assignment.key);
    final other = assignment.other;

    switch (assignment.outcome) {
      case KeyAssignmentOutcome.added:
        return null;
      case KeyAssignmentOutcome.moved:
        final from = actionName(other!);
        return switch (_language) {
          AppLanguage.german => '„$key" war vorher bei „$from"',
          AppLanguage.english => '"$key" used to be on "$from"',
        };
      case KeyAssignmentOutcome.fixed:
        final owner = actionName(other!);
        return switch (_language) {
          AppLanguage.german => '„$key" ist fest mit „$owner" belegt',
          AppLanguage.english => '"$key" is fixed to "$owner"',
        };
      case KeyAssignmentOutcome.unchanged:
        return switch (_language) {
          AppLanguage.german => '„$key" gehört schon dazu',
          AppLanguage.english => '"$key" is already bound here',
        };
    }
  }
}

// ===== PROVIDER =====

final keyboardTextsProvider = Provider<KeyboardTexts>((ref) {
  return KeyboardTexts(ref.watch(languageProvider));
});
