import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timer_provider.dart';
import 'settings_provider.dart';
import '../core/l10n/timer_texts.dart';
import '../core/theme/timer_theme.dart';

// Text Provider
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

// Button Text Provider
final startButtonTextProvider = Provider<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);

  if (timerState.isPaused) {
    return texts.resetButton;
  } else if (timerState.canStart) {
    return texts.startButton;
  } else {
    return texts.pauseButton;
  }
});

// Theme Provider
final timerBackgroundColorProvider = Provider<Color>((ref) {
  final timerState = ref.watch(timerProvider);
  return TimerTheme.getBackgroundColor(timerState);
});

final timerTextColorProvider = Provider<Color>((ref) {
  final timerState = ref.watch(timerProvider);
  return TimerTheme.getTextColor(timerState);
});

final timerFontSizeProvider = Provider<double>((ref) {
  final timerState = ref.watch(timerProvider);
  return TimerTheme.getFontSize(timerState);
});

final timerFontWeightProvider = Provider<FontWeight>((ref) {
  final timerState = ref.watch(timerProvider);
  return TimerTheme.getFontWeight(timerState);
});

// Combined UI State für Performance
class TimerUIState {
  final String formattedTime;
  final String phaseText;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final bool isWarning;

  const TimerUIState({
    required this.formattedTime,
    required this.phaseText,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.fontWeight,
    required this.isWarning,
  });
}

final timerUIStateProvider = Provider<TimerUIState>((ref) {
  return TimerUIState(
    formattedTime: ref.watch(formattedTimeProvider),
    phaseText: ref.watch(timerPhaseTextProvider),
    backgroundColor: ref.watch(timerBackgroundColorProvider),
    textColor: ref.watch(timerTextColorProvider),
    fontSize: ref.watch(timerFontSizeProvider),
    fontWeight: ref.watch(timerFontWeightProvider),
    isWarning: ref.watch(isInWarningProvider),
  );
});
