import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/timer_texts.dart';
import '../core/theme/timer_theme.dart';
import '../models/keyboard_config.dart';
import '../models/timer_state.dart';
import 'keyboard_config_provider.dart';
import 'settings_provider.dart';
import 'timer_provider.dart';

// ===== TEXT PROVIDERS =====

final timerPhaseTextProvider = Provider<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);
  return texts.getPhaseTextEnhanced(timerState);
});

final timerModeTextProvider = Provider<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);
  return texts.getModeText(timerState.mode);
});

final formattedTimeProvider = Provider<String>((ref) {
  final remainingTime = ref.watch(remainingTimeProvider);
  final settings = ref.watch(settingsProvider);
  return TimerTexts.formatTime(
    remainingTime,
    showMilliseconds: settings.showMilliseconds,
  );
});

/// Label of the start/pause control in the hint rail.
final startButtonTextProvider = Provider<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);

  if (timerState.isPaused) {
    return texts.resumeButton;
  } else if (timerState.canStart) {
    return texts.startButton;
  } else {
    return texts.pauseButton;
  }
});

/// The key currently bound to [action], formatted for a key cap.
///
/// The hint rails read the binding instead of hard-coding letters, so a
/// remapped key stays honest on screen. The space bar is special-cased: its
/// proper name ("Leertaste") does not fit on a cap.
final actionKeyLabelProvider = Provider.family<String, AppAction>((ref, action) {
  final keys = ref.watch(keyboardConfigProvider).getKeysForAction(action);
  if (keys.isEmpty) return '–';

  final key = keys.first;
  if (key == LogicalKeyboardKey.space) {
    return ref.watch(timerTextsProvider).keySpaceLabel;
  }

  return KeyboardConfig.getKeyName(key);
});

// ===== THEME PROVIDERS =====

final timerBackgroundGradientProvider = Provider<LinearGradient>((ref) {
  return TimerTheme.backgroundGradient(ref.watch(timerProvider));
});

final timerTextColorProvider = Provider<Color>((ref) {
  return TimerTheme.timeColor(ref.watch(timerProvider));
});

final timerPhaseColorProvider = Provider<Color>((ref) {
  return TimerTheme.phaseColor(ref.watch(timerProvider));
});

final timerPhaseProvider = Provider<TimerPhase>((ref) {
  return ref.watch(timerProvider).phase;
});

// ===== COMBINED UI STATE =====

/// Everything the countdown block needs, in one object.
///
/// Every field comes from a provider that only notifies when its own value
/// really changed, so this is recomputed a handful of times per phase rather
/// than ten times a second — which is also what keeps the display from
/// repainting while somebody is aiming.
class TimerUIState {
  final String formattedTime;
  final String phaseText;
  final Color timeColor;
  final Color phaseColor;
  final bool isWarning;

  const TimerUIState({
    required this.formattedTime,
    required this.phaseText,
    required this.timeColor,
    required this.phaseColor,
    required this.isWarning,
  });
}

final timerUIStateProvider = Provider<TimerUIState>((ref) {
  return TimerUIState(
    formattedTime: ref.watch(formattedTimeProvider),
    phaseText: ref.watch(timerPhaseTextProvider),
    timeColor: ref.watch(timerTextColorProvider),
    phaseColor: ref.watch(timerPhaseColorProvider),
    isWarning: ref.watch(isInWarningProvider),
  );
});
