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

  /// Hängt [key] als Zusatztaste an [action] und sagt, was passiert ist —
  /// gespeichert wird nur, wenn sich wirklich etwas geändert hat.
  KeyAssignment addExtraKey(LogicalKeyboardKey key, AppAction action) {
    final (config, assignment) = state.withExtraKey(key, action);
    if (!identical(config, state)) {
      state = config;
      _save();
    }
    return assignment;
  }

  void removeLastExtraKey(AppAction action) {
    final config = state.withoutLastExtraKey(action);
    if (identical(config, state)) return;
    state = config;
    _save();
  }

  void clearExtraKeys() {
    state = state.withoutExtraKeys();
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
