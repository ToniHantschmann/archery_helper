import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/settings_section.dart';
import '../providers/app_state_provider.dart';
import '../providers/pointer_hidden_provider.dart';
import '../screens/competition_screen.dart';
import '../screens/idle_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/timer_screen.dart';
import '../screens/traffic_light_screen.dart';
import '../widgets/keyboard_scope.dart';

class ArcheryHelperApp extends ConsumerWidget {
  const ArcheryHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Archery Helper',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const _PointerScope(child: KeyboardScope(child: AppNavigator())),
    );
  }
}

/// Blendet den Mauszeiger aus, solange über die Tastatur bedient wird.
///
/// Das Gegenstück zu `KeyboardScope`: dort kommt jede Taste herein und versteckt
/// den Zeiger, hier bringt ihn jede Mausbewegung zurück. `onHover` feuert nur
/// bei echter Bewegung — genau die gesuchte Bedingung — und erreicht diese
/// Region auch dann, wenn der Zeiger über einer Kachel mit eigenem
/// `MouseRegion` steht: Hover-Ereignisse laufen den ganzen Trefferpfad entlang,
/// nur der *Zeiger* wird von der innersten Region bestimmt.
///
/// Deshalb [MouseCursor.defer] und nicht `basic`: im sichtbaren Zustand soll
/// weiter gelten, was weiter innen steht (die Hand über den Menükacheln).
class _PointerScope extends ConsumerWidget {
  final Widget child;

  const _PointerScope({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pointerHiddenProvider);

    return MouseRegion(
      cursor: hidden ? SystemMouseCursors.none : MouseCursor.defer,
      onHover: (_) => ref.read(pointerHiddenProvider.notifier).reveal(),
      child: child,
    );
  }
}

class AppNavigator extends ConsumerWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScreen = ref.watch(currentScreenProvider);

    switch (currentScreen) {
      case AppScreen.timer:
        return const TimerScreen();
      case AppScreen.competition:
        return const CompetitionScreen();
      case AppScreen.trafficLight:
        return const TrafficLightScreen();
      case AppScreen.menu:
        return const MenuScreen();
      case AppScreen.generalSettings:
        return const SettingsScreen(section: SettingsSection.general);
      case AppScreen.timerSettings:
        return const SettingsScreen(section: SettingsSection.timer);
      case AppScreen.competitionSettings:
        return const SettingsScreen(section: SettingsSection.competition);
      case AppScreen.idle:
        return const IdleScreen();
    }
  }
}
