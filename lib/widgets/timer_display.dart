import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_providers.dart';

class TimerDisplay extends ConsumerWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(timerUIStateProvider);

    return SizedBox.expand(
      child: Column(
        children: [
          // Oberes Drittel - Phase Text
          Expanded(
            flex: 1,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 48,
                  color: uiState.textColor.withValues(alpha: 0.8),
                  fontWeight:
                      uiState.isWarning ? FontWeight.bold : FontWeight.w400,
                ),
                child: Text(uiState.phaseText, textAlign: TextAlign.center),
              ),
            ),
          ),

          // Mittleres Drittel - Timer-Anzeige
          Expanded(
            flex: 1,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 180.0,
                  fontWeight: FontWeight.w600,
                  color: uiState.textColor,
                  letterSpacing: 8,
                  height: 1.0,
                ),
                child: Text(
                  uiState.formattedTime,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'RobotoMono'),
                ),
              ),
            ),
          ),

          // Unteres Drittel - Leer
          const Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }
}
