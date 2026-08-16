import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/keyboard_config.dart';
import '../models/timer_state.dart';
import 'app_state_provider.dart';
import 'keyboard_config_provider.dart';
import 'menu_navigation_provider.dart';
import 'settings_navigation_provider.dart';
import 'timer_provider.dart';

/// Direction of an in-screen navigation step.
///
/// Deliberately separate from [AppAction]: the mapping from key binding to
/// direction happens once in [AppActionsNotifier], so every handler switches
/// over four cases the compiler can check exhaustively — no `default` clause
/// that would silently swallow a newly added direction.
enum NavigationDirection { up, down, left, right }

/// Per-screen behaviour of the actions whose meaning depends on where you are.
///
/// Everything else (timer controls, screen toggles, fullscreen) is global and
/// stays in [AppActionsNotifier]. Defaults here mean "this screen does not
/// react", so a new screen only overrides what it actually supports.
abstract class ScreenActionHandler {
  const ScreenActionHandler(this.ref);

  final Ref ref;

  /// Arrow keys — in-screen focus movement or value adjustment.
  KeyEventResult navigate(NavigationDirection direction) =>
      KeyEventResult.ignored;

  /// Confirm / select the focused element.
  KeyEventResult confirm() => KeyEventResult.ignored;

  /// Context-sensitive "further": advance the timer, activate a row, ...
  KeyEventResult next() => KeyEventResult.ignored;

  /// Leave / close.
  KeyEventResult back() => KeyEventResult.ignored;

  /// Reset. Defaults to resetting the timer, which is what the key means on
  /// every screen — the timer keeps running while you are elsewhere.
  KeyEventResult resetTimer() {
    ref.read(timerProvider.notifier).resetTimer();
    return KeyEventResult.handled;
  }

  void goTo(AppScreen screen) =>
      ref.read(appStateProvider.notifier).navigateToScreen(screen);
}

class TimerScreenActions extends ScreenActionHandler {
  const TimerScreenActions(super.ref);

  @override
  KeyEventResult confirm() {
    ref.read(timerProvider.notifier).toggle();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult next() {
    ref.read(timerProvider.notifier).advance();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult back() {
    goTo(AppScreen.menu);
    return KeyEventResult.handled;
  }
}

class SettingsScreenActions extends ScreenActionHandler {
  const SettingsScreenActions(super.ref);

  SettingsNavigationNotifier get _navigation =>
      ref.read(settingsNavigationProvider.notifier);

  @override
  KeyEventResult navigate(NavigationDirection direction) {
    switch (direction) {
      case NavigationDirection.up:
        _navigation.moveUp();
      case NavigationDirection.down:
        _navigation.moveDown();
      case NavigationDirection.left:
        _navigation.adjustLeft();
      case NavigationDirection.right:
        _navigation.adjustRight();
    }
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult confirm() {
    _navigation.activate();
    return KeyEventResult.handled;
  }

  /// Space activates the focused row here rather than advancing the timer.
  @override
  KeyEventResult next() => confirm();

  @override
  KeyEventResult back() {
    // A pending reset confirmation is cancelled first — only a second Esc
    // leaves the screen.
    if (_navigation.disarmReset()) {
      return KeyEventResult.handled;
    }

    // Back to the timer, not the menu: that is where you came from in
    // practice, and MenuScreen is still a placeholder.
    goTo(AppScreen.timer);
    return KeyEventResult.handled;
  }
}

class MenuScreenActions extends ScreenActionHandler {
  const MenuScreenActions(super.ref);

  MenuNavigationNotifier get _navigation =>
      ref.read(menuNavigationProvider.notifier);

  @override
  KeyEventResult navigate(NavigationDirection direction) {
    switch (direction) {
      case NavigationDirection.up:
        _navigation.moveUp();
      case NavigationDirection.down:
        _navigation.moveDown();
      // The menu is a single column; left/right have nothing to step through.
      case NavigationDirection.left:
      case NavigationDirection.right:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult confirm() {
    goTo(ref.read(menuNavigationProvider).target);
    return KeyEventResult.handled;
  }

  /// Space opens the focused entry here rather than advancing the timer.
  @override
  KeyEventResult next() => confirm();

  @override
  KeyEventResult back() {
    goTo(AppScreen.timer);
    return KeyEventResult.handled;
  }
}

class IdleScreenActions extends ScreenActionHandler {
  const IdleScreenActions(super.ref);

  /// The idle screen says "press any key to start", so anything meaningful
  /// wakes it into the timer.
  @override
  KeyEventResult confirm() => _wake();

  @override
  KeyEventResult next() => _wake();

  @override
  KeyEventResult back() => _wake();

  KeyEventResult _wake() {
    goTo(AppScreen.timer);
    return KeyEventResult.handled;
  }
}

/// Picks the handler for the current screen. The switch is exhaustive, so
/// adding an [AppScreen] forces a decision about its key handling instead of
/// silently falling through.
final screenActionHandlerProvider = Provider<ScreenActionHandler>((ref) {
  final screen = ref.watch(currentScreenProvider);

  switch (screen) {
    case AppScreen.timer:
      return TimerScreenActions(ref);
    case AppScreen.settings:
      return SettingsScreenActions(ref);
    case AppScreen.menu:
      return MenuScreenActions(ref);
    case AppScreen.idle:
      return IdleScreenActions(ref);
  }
});

/// Single dispatch point for every keyboard-driven action.
///
/// Global actions are handled here; screen-dependent ones are delegated to the
/// [ScreenActionHandler] of the current screen.
class AppActionsNotifier {
  final Ref ref;

  AppActionsNotifier(this.ref);

  /// Actions that may fire repeatedly while a key is held down. Stepping a
  /// value should repeat; starting the timer must not.
  static const _repeatableActions = {
    AppAction.navigateUp,
    AppAction.navigateDown,
    AppAction.navigateLeft,
    AppAction.navigateRight,
  };

  /// [isRepeat] marks auto-repeat events; see [_repeatableActions].
  KeyEventResult handleKeyPress(
    LogicalKeyboardKey key, {
    bool isRepeat = false,
  }) {
    final action = ref.read(keyboardConfigProvider).getAction(key);

    if (action == null) {
      return KeyEventResult.ignored;
    }

    if (isRepeat && !_repeatableActions.contains(action)) {
      return KeyEventResult.ignored;
    }

    return handleAction(action);
  }

  KeyEventResult handleAction(AppAction action) {
    final screen = ref.read(screenActionHandlerProvider);

    switch (action) {
      // ── Screen-dependent ────────────────────────────────────
      case AppAction.navigateUp:
        return screen.navigate(NavigationDirection.up);
      case AppAction.navigateDown:
        return screen.navigate(NavigationDirection.down);
      case AppAction.navigateLeft:
        return screen.navigate(NavigationDirection.left);
      case AppAction.navigateRight:
        return screen.navigate(NavigationDirection.right);
      case AppAction.confirm:
        return screen.confirm();
      case AppAction.next:
        return screen.next();
      case AppAction.back:
        return screen.back();
      case AppAction.resetTimer:
        return screen.resetTimer();

      // ── Global ──────────────────────────────────────────────
      case AppAction.toggleTimer:
        ref.read(timerProvider.notifier).toggle();
        return KeyEventResult.handled;

      case AppAction.skipTimer:
        ref.read(timerProvider.notifier).skipTimerPhase();
        return KeyEventResult.handled;

      case AppAction.nextMode:
        _cycleMode(1);
        return KeyEventResult.handled;

      case AppAction.previousMode:
        _cycleMode(-1);
        return KeyEventResult.handled;

      case AppAction.toggleMenu:
        _toggleScreen(AppScreen.menu);
        return KeyEventResult.handled;

      case AppAction.toggleSettings:
        _toggleScreen(AppScreen.settings);
        return KeyEventResult.handled;

      case AppAction.toggleFullscreen:
        ref.read(appStateProvider.notifier).toggleFullscreen();
        //TODO: implement real full screen
        return KeyEventResult.handled;
    }
  }

  void _cycleMode(int delta) {
    final modes = TimerMode.values;
    final currentIndex = modes.indexOf(ref.read(timerProvider).mode);
    final nextIndex = (currentIndex + delta + modes.length) % modes.length;

    ref.read(timerProvider.notifier).setMode(modes[nextIndex]);
  }

  /// Toggling a screen you are already on returns to the timer.
  void _toggleScreen(AppScreen screen) {
    final current = ref.read(currentScreenProvider);
    ref
        .read(appStateProvider.notifier)
        .navigateToScreen(current == screen ? AppScreen.timer : screen);
  }
}

final appActionsProvider = Provider<AppActionsNotifier>((ref) {
  return AppActionsNotifier(ref);
});
