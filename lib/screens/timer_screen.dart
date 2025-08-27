import '../models/timer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../providers/ui_providers.dart';
import '../providers/app_state_provider.dart';
import '../widgets/timer_display.dart';
import '../widgets/debug_panel.dart';
import '../core/l10n/timer_texts.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focus für Keyboard-Eingaben
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final timerState = ref.watch(timerProvider);
    final uiState = ref.watch(timerUIStateProvider);

    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: uiState.backgroundColor,
          child: Stack(
            children: [
              // Haupt-Timer Display
              const TimerDisplay(),

              // Debug Panel (oben rechts) - nur für Development
              if (kDebugMode)
                const Positioned(top: 20, right: 20, child: DebugPanel()),

              // Control Buttons (unten) - für Testing ohne Keyboard
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: _buildControlButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Nur auf Key-Down reagieren
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final appActions = ref.read(appActionsProvider);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        appActions.handleSpacePress();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        appActions.handleEnterPress();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.escape:
        appActions.handleEscapePress();
        return KeyEventResult.handled;

      // Zusätzliche Debug-Keys
      case LogicalKeyboardKey.keyR:
        ref.read(timerProvider.notifier).resetTimer();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyN:
        // Nächster Timer-Modus (zum Testen)
        _switchToNextMode();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  void _switchToNextMode() {
    final currentMode = ref.read(timerProvider).mode;
    final modes = TimerMode.values;
    final currentIndex = modes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % modes.length;

    ref.read(timerProvider.notifier).setMode(modes[nextIndex]);
  }

  Widget _buildControlButtons() {
    final timerState = ref.watch(timerProvider);
    final startButtonText = ref.watch(startButtonTextProvider);
    final modeText = ref.watch(timerModeTextProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer Mode Indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              modeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Control Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Start/Pause Button
              _buildControlButton(
                text: startButtonText,
                onPressed:
                    timerState.canStart ||
                            timerState.canPause ||
                            timerState.canResume
                        ? () => ref.read(appActionsProvider).handleSpacePress()
                        : null,
                isPrimary: true,
              ),

              const SizedBox(width: 20),

              // Reset Button
              _buildControlButton(
                text: TimerTexts.resetButton,
                onPressed:
                    timerState.canReset
                        ? () => ref.read(timerProvider.notifier).resetTimer()
                        : null,
              ),

              const SizedBox(width: 20),

              // Mode Switch Button (nur für Testing)
              _buildControlButton(
                text: 'Nächster Modus',
                onPressed: () => _switchToNextMode(),
                isSecondary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String text,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isSecondary = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPrimary
                ? Colors.green.withOpacity(0.8)
                : isSecondary
                ? Colors.orange.withOpacity(0.8)
                : Colors.grey.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: Text(text),
    );
  }
}
