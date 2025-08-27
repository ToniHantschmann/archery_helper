import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../screens/timer_screen.dart';

class ArcheryHelperApp extends ConsumerWidget {
  const ArcheryHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Archery Helper',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AppNavigator(),
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
      default:
        return const IdleScreen();
    }
  }
}

// Placeholder Screens (werden später implementiert)
class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bogensport Timer',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Drücken Sie eine beliebige Taste zum Starten',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Menü - Wird später implementiert',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Einstellungen - Wird später implementiert',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
