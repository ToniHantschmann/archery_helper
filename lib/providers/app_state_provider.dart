import '../providers/timer_provider.dart';
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

  // Keyboard Shortcuts
  void handleSpacePress() {
    final timerState = ref.read(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    if (timerState.canStart || timerState.isPaused) {
      timerNotifier.startTimer();
    } else if (timerState.isRunning) {
      timerNotifier.pauseTimer();
    }
  }

  void handleEnterPress() {
    final currentScreen = ref.read(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        final timerNotifier = ref.read(timerProvider.notifier);
        timerNotifier.resetTimer();
        break;
      case AppScreen.menu:
        // Enter in Menu = Select item
        break;
      default:
        // Navigate to timer
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
    }
  }

  void handleEscapePress() {
    final currentScreen = ref.read(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
        break;
      case AppScreen.settings:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
        break;
      case AppScreen.menu:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.timer);
        break;
      default:
        ref.read(appStateProvider.notifier).navigateToScreen(AppScreen.idle);
    }
  }
}

final appActionsProvider = Provider<AppActionsNotifier>((ref) {
  return AppActionsNotifier(ref);
});
