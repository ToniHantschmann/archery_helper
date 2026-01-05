import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  await container.read(settingsProvider.notifier).loadSettings();
  await container.read(keyboardConfigProvider.notifier).loadConfig();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArcheryHelperApp(),
    ),
  );
}
