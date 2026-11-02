import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/keyboard_config.dart';
import 'keyboard_config_provider.dart';

/// Was der Tastenbelegungs-Screen an Zustand hat.
///
/// Dasselbe Muster wie `SettingsNavState`: Auswahl, Aufnahme und die scharfe
/// Reset-Bestätigung sind ein Objekt, weil das Weiterwandern der Auswahl die
/// anderen beiden mitbeendet.
class KeyboardNavState {
  /// Die ausgewählte Zeile — `null` ist die Reset-Zeile am Ende, die einzige,
  /// die keine Aktion ist (wie `MenuItem.quit` das eine Menüziel ohne Screen).
  final AppAction? selected;

  /// True, solange die ausgewählte Zeile auf die neue Taste wartet. Die
  /// Tasten kommen dann über `ScreenActionHandler.textInput`, an der
  /// Tastenbelegung vorbei.
  final bool capturing;

  /// True, solange die Reset-Zeile auf die zweite Bestätigung wartet.
  final bool resetArmed;

  /// Wie die letzte Aufnahme in der ausgewählten Zeile ausgegangen ist; die
  /// Zeile sagt es dazu, bis die Auswahl weiterwandert.
  final KeyAssignment? notice;

  const KeyboardNavState({
    this.selected = _firstRow,
    this.capturing = false,
    this.resetArmed = false,
    this.notice,
  });

  static const _firstRow = AppAction.toggleTimer;
}

/// Die Zeilen in Anzeigereihenfolge: jede Aktion, dann die Reset-Zeile.
const List<AppAction?> keyboardRows = [...AppAction.values, null];

/// Owns the focused row of the key binding screen and the capture of a new
/// key. Like the settings navigation, the keyboard path
/// (`KeyboardSettingsScreenActions`) and taps drive the same state.
class KeyboardNavigationNotifier extends Notifier<KeyboardNavState> {
  @override
  KeyboardNavState build() => const KeyboardNavState();

  KeyboardConfigNotifier get _config =>
      ref.read(keyboardConfigProvider.notifier);

  bool get isCapturing => state.capturing;

  /// Moving the selection ends whatever the old row had going: an armed reset,
  /// a running capture, a notice about the last one.
  void select(AppAction? row) {
    if (row == state.selected) return;
    state = KeyboardNavState(selected: row);
  }

  void moveUp() => _move(-1);

  void moveDown() => _move(1);

  void _move(int delta) {
    final index = keyboardRows.indexOf(state.selected);
    final next = (index + delta + keyboardRows.length) % keyboardRows.length;
    select(keyboardRows[next]);
  }

  /// Enter/Space: auf einer Aktion die Aufnahme starten, auf der Reset-Zeile
  /// erst scharf schalten und beim zweiten Mal alle Zusatztasten entfernen.
  void activate() {
    final action = state.selected;

    if (action == null) {
      if (state.resetArmed) {
        _config.clearExtraKeys();
        state = const KeyboardNavState(selected: null);
      } else {
        state = const KeyboardNavState(selected: null, resetArmed: true);
      }
      return;
    }

    state = KeyboardNavState(selected: action, capturing: true);
  }

  /// Hängt [key] an die Aktion, auf die gewartet wurde, und beendet die
  /// Aufnahme — auch wenn die Taste abgelehnt wird: die Zeile sagt dann
  /// warum, und ein zweites Enter versucht es noch einmal.
  void capture(LogicalKeyboardKey key) {
    final action = state.selected;
    if (!state.capturing || action == null) return;

    final assignment = _config.addExtraKey(key, action);
    state = KeyboardNavState(selected: action, notice: assignment);
  }

  void cancelCapture() {
    if (!state.capturing) return;
    state = KeyboardNavState(selected: state.selected);
  }

  /// Entfernt die zuletzt hinzugefügte Zusatztaste der ausgewählten Zeile.
  void removeLast() {
    final action = state.selected;
    if (action == null) return;

    _config.removeLastExtraKey(action);
    state = KeyboardNavState(selected: action);
  }

  /// Cancels a pending reset confirmation. Returns whether there was one, so
  /// the first Esc is spent here and only the second leaves the screen.
  bool disarmReset() {
    if (!state.resetArmed) return false;
    state = KeyboardNavState(selected: state.selected);
    return true;
  }
}

/// `autoDispose` aus demselben Grund wie `settingsNavigationProvider`: die
/// Auswahl lebt so lange wie der Screen, der sie zeigt, und der nächste Besuch
/// fängt oben an statt mitten im Aufbau etwas Veraltetes nachzuholen.
final keyboardNavigationProvider =
    NotifierProvider.autoDispose<KeyboardNavigationNotifier, KeyboardNavState>(
      () => KeyboardNavigationNotifier(),
    );

/// The focused row, for scrolling it into view.
final selectedKeyboardRowProvider = Provider.autoDispose<AppAction?>((ref) {
  return ref.watch(keyboardNavigationProvider).selected;
});

/// Whether a single row is focused — per row, so a moving selection rebuilds
/// only the two rows involved.
final isKeyboardRowSelectedProvider = Provider.autoDispose
    .family<bool, AppAction?>((ref, row) {
      return ref.watch(selectedKeyboardRowProvider) == row;
    });

/// Whether a key is being captured at all — the hint rail swaps its keys then.
final isKeyboardCapturingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(keyboardNavigationProvider).capturing;
});

/// Whether [action]'s row waits for its new key.
final isKeyboardRowCapturingProvider = Provider.autoDispose
    .family<bool, AppAction>((ref, action) {
      return ref.watch(isKeyboardRowSelectedProvider(action)) &&
          ref.watch(isKeyboardCapturingProvider);
    });

/// The outcome of the last capture on [action]'s row, or `null`.
final keyboardRowNoticeProvider = Provider.autoDispose
    .family<KeyAssignment?, AppAction>((ref, action) {
      final state = ref.watch(keyboardNavigationProvider);
      return state.selected == action ? state.notice : null;
    });

/// Whether the reset row awaits its second confirmation.
final isKeyboardResetArmedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(keyboardNavigationProvider).resetArmed;
});

/// [action]'s default and extra keys, for its row.
///
/// Changes only when a binding changes, and then every row rebuilds — a list
/// never compares equal to a fresh one. That is a handful of rows on a key
/// press in this screen, not a per-tick cost.
final actionBindingsProvider = Provider.autoDispose
    .family<
      ({List<LogicalKeyboardKey> defaults, List<LogicalKeyboardKey> extras}),
      AppAction
    >((ref, action) {
      final config = ref.watch(keyboardConfigProvider);
      return (
        defaults: config.defaultKeysFor(action),
        extras: config.extraKeysFor(action),
      );
    });
