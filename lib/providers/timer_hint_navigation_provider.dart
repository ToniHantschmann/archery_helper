import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_actions_provider.dart';
import 'ui_providers.dart';

/// Owns which entry of the timer screen's bottom hint rail is focused.
///
/// Same split as the settings/menu navigation notifiers: this holds the
/// selection, the rail only renders it, and moveLeft/moveRight/activate are
/// how left/right and Enter reach it. There is no separate mouse path to keep
/// in sync — [activate] dispatches through [appActionsProvider], the same
/// path a [KeyHint.onTap] or the bound key would take.
class TimerHintNavigationNotifier extends Notifier<int> {
  @override
  int build() {
    // The list shrinks when entering manual mode (see timerHintActionsProvider).
    // A focused index past the new end would stay selected but unreachable, so
    // it snaps back to the first entry instead.
    ref.listen(timerHintActionsProvider, (previous, next) {
      if (state >= next.length) {
        state = 0;
      }
    });
    return 0;
  }

  void moveLeft() => _move(-1);

  void moveRight() => _move(1);

  void _move(int delta) {
    final count = ref.read(timerHintActionsProvider).length;
    state = (state + delta + count) % count;
  }

  /// Fires the action bound to the focused hint.
  void activate() {
    final actions = ref.read(timerHintActionsProvider);
    ref.read(appActionsProvider).handleAction(actions[state]);
  }
}

final timerHintNavigationProvider =
    NotifierProvider<TimerHintNavigationNotifier, int>(
      () => TimerHintNavigationNotifier(),
    );

/// Whether a single hint is focused — watched per entry so moving the
/// selection rebuilds only the two hints involved.
final isTimerHintSelectedProvider = Provider.family<bool, int>((ref, index) {
  return ref.watch(timerHintNavigationProvider) == index;
});
