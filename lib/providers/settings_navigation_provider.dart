import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/app_language.dart';
import '../models/timer_state.dart';
import 'settings_provider.dart';

/// All keyboard-selectable rows of the settings screen, in visual order.
/// The order defines what navigateUp/navigateDown step through.
enum SettingsItem {
  language,
  soundEnabled,
  volume,
  defaultMode,
  autoStart,
  showMilliseconds,
  customPrepTime,
  customMainTime,
  resetToDefaults,
}

/// Step width used when adjusting a duration with navigateLeft/navigateRight.
const _durationStep = Duration(seconds: 1);

/// Duration values are kept inside this range (1 hour is far beyond any
/// sensible shooting time, but keeps key repeat from running away).
const _maxDurationSeconds = 3600;

/// Volume moves in the same 10 steps the slider offers.
const _volumeSteps = 10;

class SettingsNavState {
  final SettingsItem selected;

  /// True while the reset row awaits a second confirmation.
  ///
  /// This is genuine state, not a one-shot event: the row renders differently
  /// while armed, and it is cleared by confirming, by Esc, or by moving away.
  /// That keeps the confirmation entirely inside the provider — no dialog
  /// route, no BuildContext, and the same flow for mouse and keyboard.
  final bool resetArmed;

  const SettingsNavState({
    this.selected = SettingsItem.language,
    this.resetArmed = false,
  });

  SettingsNavState copyWith({SettingsItem? selected, bool? resetArmed}) {
    return SettingsNavState(
      selected: selected ?? this.selected,
      resetArmed: resetArmed ?? this.resetArmed,
    );
  }
}

/// Owns which settings row is focused and translates the navigate* actions
/// into changes on [settingsProvider]. Kept separate from the widget so the
/// keyboard path (AppActionsNotifier) and the mouse path (taps in
/// SettingsScreen) drive exactly the same state.
class SettingsNavigationNotifier extends Notifier<SettingsNavState> {
  @override
  SettingsNavState build() => const SettingsNavState();

  /// Called when the settings screen is entered, so navigation always starts
  /// at the top instead of wherever it was left last time.
  void reset() {
    state = const SettingsNavState();
  }

  void select(SettingsItem item) {
    // Moving away from an armed reset cancels it.
    state = state.copyWith(
      selected: item,
      resetArmed: item == state.selected && state.resetArmed,
    );
  }

  void moveUp() => _move(-1);

  void moveDown() => _move(1);

  void adjustLeft() => _adjust(-1);

  void adjustRight() => _adjust(1);

  /// Confirm/next on the focused row: toggles switches, arms and then performs
  /// the reset.
  void activate() {
    final notifier = ref.read(settingsProvider.notifier);

    switch (state.selected) {
      case SettingsItem.soundEnabled:
        notifier.toggleSound();

      case SettingsItem.autoStart:
        notifier.toggleAutoStart();

      case SettingsItem.showMilliseconds:
        notifier.toggleShowMilliseconds();

      case SettingsItem.resetToDefaults:
        if (state.resetArmed) {
          notifier.resetToDefaults();
          state = state.copyWith(resetArmed: false);
        } else {
          state = state.copyWith(resetArmed: true);
        }

      // Enums and numbers cycle forward, so confirm behaves like navigateRight.
      case SettingsItem.language:
      case SettingsItem.defaultMode:
      case SettingsItem.volume:
      case SettingsItem.customPrepTime:
      case SettingsItem.customMainTime:
        _adjust(1);
    }
  }

  /// Cancels a pending reset confirmation.
  /// Returns whether there was one — the caller uses that to decide whether
  /// Esc was consumed here or should leave the screen.
  bool disarmReset() {
    if (!state.resetArmed) return false;

    state = state.copyWith(resetArmed: false);
    return true;
  }

  void _move(int delta) {
    final items = _selectableItems();
    final currentIndex = items.indexOf(state.selected);

    // The current row can be unselectable (volume with sound off) if the value
    // changed after selection — fall back to the start of the list.
    if (currentIndex == -1) {
      select(items.first);
      return;
    }

    final nextIndex = (currentIndex + delta + items.length) % items.length;
    select(items[nextIndex]);
  }

  /// Rows that can currently hold focus. Volume is skipped while sound is off,
  /// because its slider is disabled and would be a dead stop.
  List<SettingsItem> _selectableItems() {
    final soundEnabled = ref.read(settingsProvider).soundEnabled;

    return SettingsItem.values
        .where((item) => item != SettingsItem.volume || soundEnabled)
        .toList();
  }

  void _adjust(int delta) {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    switch (state.selected) {
      case SettingsItem.language:
        notifier.setLanguage(
          _cycle(AppLanguage.values, settings.language, delta),
        );

      case SettingsItem.soundEnabled:
        if (settings.soundEnabled != (delta > 0)) {
          notifier.toggleSound();
        }

      case SettingsItem.volume:
        if (!settings.soundEnabled) return;
        // Work in whole slider steps to avoid floating point drift.
        final steps = (settings.volume * _volumeSteps).round() + delta;
        notifier.setVolume(steps.clamp(0, _volumeSteps) / _volumeSteps);

      case SettingsItem.defaultMode:
        notifier.setDefaultMode(
          _cycle(TimerMode.values, settings.defaultMode, delta),
        );

      case SettingsItem.autoStart:
        if (settings.autoStart != (delta > 0)) {
          notifier.toggleAutoStart();
        }

      case SettingsItem.showMilliseconds:
        if (settings.showMilliseconds != (delta > 0)) {
          notifier.toggleShowMilliseconds();
        }

      case SettingsItem.customPrepTime:
        notifier.setCustomPrepTime(_step(settings.customPrepTime, delta));

      case SettingsItem.customMainTime:
        notifier.setCustomMainTime(_step(settings.customMainTime, delta));

      case SettingsItem.resetToDefaults:
        // Nothing to adjust — only confirm acts on this row.
        break;
    }
  }

  Duration _step(Duration current, int delta) {
    final seconds = current.inSeconds + (_durationStep.inSeconds * delta);
    return Duration(seconds: seconds.clamp(0, _maxDurationSeconds));
  }

  T _cycle<T>(List<T> values, T current, int delta) {
    final index = values.indexOf(current);
    final nextIndex = (index + delta + values.length) % values.length;
    return values[nextIndex];
  }
}

final settingsNavigationProvider =
    NotifierProvider<SettingsNavigationNotifier, SettingsNavState>(
      () => SettingsNavigationNotifier(),
    );

/// Convenience provider: the currently focused row.
final selectedSettingsItemProvider = Provider<SettingsItem>((ref) {
  return ref.watch(settingsNavigationProvider).selected;
});

/// Whether a single row is focused. Used per row so that moving the selection
/// only rebuilds the two rows involved instead of the whole screen.
final isSettingsItemSelectedProvider = Provider.family<bool, SettingsItem>((
  ref,
  item,
) {
  return ref.watch(selectedSettingsItemProvider) == item;
});

/// Whether the reset row currently awaits confirmation.
final isResetArmedProvider = Provider<bool>((ref) {
  return ref.watch(settingsNavigationProvider).resetArmed;
});
