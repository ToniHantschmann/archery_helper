import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/keyboard_config.dart';
import '../repositories/keyboard_config_repository.dart';

final keyboardConfigRepositoryProvider = Provider<KeyboardConfigRepository>((
  ref,
) {
  return KeyboardConfigRepository();
});

/// provider for keyboard config
class KeyboardConfigNotifier extends Notifier<KeyboardConfig> {
  late final KeyboardConfigRepository _repository;

  @override
  KeyboardConfig build() {
    _repository = ref.watch(keyboardConfigRepositoryProvider);
    return KeyboardConfig.defaults();
  }

  Future<void> loadConfig() async {
    state = await _repository.loadConfig();
  }

  Future<void> _save() async {
    await _repository.saveConfig(state);
  }

  void setKeyBinding(LogicalKeyboardKey key, AppAction action) {
    state = state.addKeyBinding(key, action);
    _save();
  }

  void removeKeyBinding(LogicalKeyboardKey key) {
    state = state.removeKeyBinding(key);
    _save();
  }

  void resetToDefaults() {
    state = KeyboardConfig.defaults();
    _save();
  }
}

/// main provider for keyboard configuration
final keyboardConfigProvider =
    NotifierProvider<KeyboardConfigNotifier, KeyboardConfig>(
      () => KeyboardConfigNotifier(),
    );

/// convenience provider: returns action for key
final keyActionProvider = Provider.family<AppAction?, LogicalKeyboardKey>((
  ref,
  key,
) {
  return ref.watch(keyboardConfigProvider).getAction(key);
});
