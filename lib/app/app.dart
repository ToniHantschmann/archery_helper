import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../screens/idle_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/timer_screen.dart';
import '../widgets/keyboard_scope.dart';

class ArcheryHelperApp extends ConsumerWidget {
  const ArcheryHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Archery Helper',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const KeyboardScope(child: AppNavigator()),
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
      case AppScreen.menu:
        return const MenuScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.idle:
        return const IdleScreen();
    }
  }
}
