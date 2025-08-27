import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_providers.dart';
import '../core/l10n/timer_texts.dart';

class TimerDisplay extends ConsumerWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(timerUIStateProvider);

    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Haupt-Timer Display
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: uiState.fontSize,
              fontWeight: uiState.fontWeight,
              color: uiState.textColor,
              fontFamily: 'monospace',
            ),
            child: Text(uiState.formattedTime, textAlign: TextAlign.center),
          ),

          const SizedBox(height: 30),

          // Phase Text
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: uiState.isWarning ? 56 : 48,
              color: uiState.textColor,
              fontWeight: uiState.isWarning ? FontWeight.bold : FontWeight.w400,
            ),
            child: Text(uiState.phaseText, textAlign: TextAlign.center),
          ),

          const Spacer(),

          // Keyboard Hints (unten)
          Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: Text(
              '${TimerTexts.keyboardHints} • [R] Reset • [N] Nächster Modus',
              style: TextStyle(
                fontSize: 18,
                color: uiState.textColor.withOpacity(0.6),
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
