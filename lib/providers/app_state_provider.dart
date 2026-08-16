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

class AppStateNotifier extends Notifier<AppState> {
  @override
  AppState build() {
    return AppState(sessionStart: DateTime.now());
  }

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

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  () => AppStateNotifier(),
);

// ===== CURRENT SCREEN PROVIDER =====
final currentScreenProvider = Provider<AppScreen>((ref) {
  return ref.watch(appStateProvider).currentScreen;
});
