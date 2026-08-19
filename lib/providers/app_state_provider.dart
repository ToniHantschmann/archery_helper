import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jeder Screen der App — ein Wert pro Vollbildseite.
///
/// Die Einstellungen sind drei Screens, nicht einer: was zur Ampel gehört, wird
/// bei der Ampel eingestellt, was zum Wettkampf gehört, beim Wettkampf. Jeder
/// neue Wert hier erzwingt eine Entscheidung in `AppNavigator` und in
/// `screenActionHandlerProvider` — beide schalten erschöpfend über dieses Enum.
enum AppScreen {
  timer,
  competition,
  trafficLight,
  menu,
  generalSettings,
  timerSettings,
  competitionSettings,
  idle,
}

class AppState {
  final AppScreen currentScreen;
  final DateTime sessionStart;

  const AppState({
    // The menu is the home screen: the app is a collection of tunnel helpers,
    // and the timer is only the first of them.
    this.currentScreen = AppScreen.menu,
    required this.sessionStart,
  });

  AppState copyWith({AppScreen? currentScreen, DateTime? sessionStart}) {
    return AppState(
      currentScreen: currentScreen ?? this.currentScreen,
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
