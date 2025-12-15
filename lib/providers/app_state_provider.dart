import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../models/timer_state.dart';
import '../providers/timer_provider.dart';
import '../models/keyboard_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { timer, menu, settings, idle }

class AppState {
  final AppScreen currentScreen;
  final bool isFullscreen;
  final DateTime sessionStart;

  const AppState({
    this.currentScreen = AppScreen.timer,
    this.isFullscreen = true,
    required this.sessionStart,
  });

  AppState copyWith({
    AppScreen? currentScreen,
    bool? isFullscreen,
    DateTime? sessionStart,
  }) {
    return AppState(
      currentScreen: currentScreen ?? this.currentScreen,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      sessionStart: sessionStart ?? this.sessionStart,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(AppState(sessionStart: DateTime.now()));

  void navigateToScreen(AppScreen screen) {
    state = state.copyWith(currentScreen: screen);
  }

  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  void startNewSession() {
    state = state.copyWith(sessionStart: DateTime.now());
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(),
);

// ===== CURRENT SCREEN PROVIDER =====
final currentScreenProvider = Provider<AppScreen>((ref) {
  return ref.watch(appStateProvider).currentScreen;
});

// ===== COMBINED APP PROVIDER =====
// Für Shortcuts und globale Actions
class AppActionsNotifier {
  final Ref ref;

  AppActionsNotifier(this.ref);

  KeyEventResult handleKeyPress(LogicalKeyboardKey key) {
    final keyboardConfig = ref.read(keyboardConfigProvider);
    final action = keyboardConfig.getAction(key);

    if (action == null) {
      return KeyEventResult.ignored;
    }

    return handleAction(action);
  }

  KeyEventResult handleAction(AppAction action) {
    switch (action) {
      case AppAction.toggleTimer:
        _handleToggleTimer();
        return KeyEventResult.handled;

      case AppAction.resetTimer:
        _handleResetTimer();
        return KeyEventResult.handled;

      case AppAction.nextMode:
        _handleNextMode();
        return KeyEventResult.handled;

      case AppAction.previousMode:
        _handlePreviousMode();
        return KeyEventResult.handled;

      case AppAction.toggleMenu:
        _handleToggleMenu();
        return KeyEventResult.handled;

      case AppAction.toggleSettings:
        _handleToggleSettings();
        return KeyEventResult.handled;

      case AppAction.back:
        _handleBack();
        return KeyEventResult.handled;

      case AppAction.confirm:
        _handleConfirm();
        return KeyEventResult.handled;

      case AppAction.toggleFullscreen:
        _handleToggleFullscreen();
        return KeyEventResult.handled;

      case AppAction.skipTimer:
        _handleSkipTimer();
        return KeyEventResult.handled;

      case AppAction.next:
        _handleNext();
        return KeyEventResult.handled;
    }
  }

  // private implementations
  void _handleToggleTimer() {
    final timerState = ref.read(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    if (timerState.isPaused) {
      timerNotifier.startTimer();
    } else if (timerState.isRunning) {
      timerNotifier.pauseTimer();
    }
  }

  void _handleResetTimer() {
    final currentScreen = ref.read(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        final timerNotifier = ref.read(timerProvider.notifier);
        timerNotifier.resetTimer();
        break;

      case AppScreen.menu:
        //TODO what to do here?
        break;
      default:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
    }
  }

  void _handleNextMode() {
    final currentMode = ref.read(timerProvider).mode;
    final modes = TimerMode.values;
    final currentIndex = modes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % modes.length;

    ref.read(timerProvider.notifier).setMode(modes[nextIndex]);
  }

  void _handlePreviousMode() {
    final currentMode = ref.read(timerProvider).mode;
    final modes = TimerMode.values;
    final currentIndex = modes.indexOf(currentMode);
    final nextIndex = (currentIndex - 1 + modes.length) % modes.length;

    ref.read(timerProvider.notifier).setMode(modes[nextIndex]);
  }

  void _handleToggleMenu() {
    final currenScreen = ref.read(currentScreenProvider);

    if (currenScreen == AppScreen.menu) {
      // if in menu go to timer
      ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
    } else {
      ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
    }
  }

  void _handleToggleSettings() {
    final currenScreen = ref.read(currentScreenProvider);

    if (currenScreen == AppScreen.settings) {
      // if in settings go to timer
      ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
    } else {
      ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.settings);
    }
  }

  void _handleBack() {
    final currentScreen = ref.read(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
        break;

      case AppScreen.settings:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
        break;

      case AppScreen.menu:
        // do nothing
        break;
      default:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.idle);
    }
  }

  void _handleConfirm() {
    final currentScreen = ref.read(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        _handleToggleTimer();
        break;

      case AppScreen.menu:
        // choose selected element in menu
        //TODO: implement when we have a menu and navigation there
        break;
      default:
        break;
    }
  }

  void _handleToggleFullscreen() {
    ref.read(appStateProvider.notifier).toggleFullscreen();
    //TODO: implement real full screen
  }

  void _handleSkipTimer() {
    ref.read(timerProvider.notifier).skipTimerPhase();
  }

  void _handleNext() {
    final timerState = ref.read(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    if (timerState.canStart || timerState.isPaused || timerState.isFinished) {
      timerNotifier.startTimer();
    } else if (timerState.isRunning) {
      _handleSkipTimer();
    }
  }
}

final appActionsProvider = Provider<AppActionsNotifier>((ref) {
  return AppActionsNotifier(ref);
});
