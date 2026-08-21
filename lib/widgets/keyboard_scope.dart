import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_actions_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/pointer_hidden_provider.dart';

/// App-wide keyboard entry point.
///
/// Wraps the whole screen stack so every screen is keyboard operable — the app
/// is a kiosk display without mouse or touch, so a screen that does not receive
/// key events is a screen you cannot leave. All events are delegated to
/// [AppActionsNotifier]; screens never handle raw keys themselves.
///
/// Routes pushed on top (dialogs) are siblings of this widget in the Navigator
/// overlay, not descendants — they keep their own key handling and are not
/// affected by this scope.
class KeyboardScope extends ConsumerStatefulWidget {
  final Widget child;

  const KeyboardScope({super.key, required this.child});

  @override
  ConsumerState<KeyboardScope> createState() => _KeyboardScopeState();
}

class _KeyboardScopeState extends ConsumerState<KeyboardScope> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'KeyboardScope');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _requestFocus() {
    if (mounted && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A screen change can leave focus on a widget of the old screen (or on a
    // button clicked with the mouse) — take it back so keys keep working.
    ref.listen(currentScreenProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestFocus());
    });

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      // Nothing below may take focus, so this node cannot lose it to a button
      // that happened to be clicked — the scope keeps receiving keys without
      // having to fight for focus back. Routes pushed on top (dialogs, dropdown
      // overlays) are outside this subtree and keep their own focus handling.
      child: ExcludeFocus(child: widget.child),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Wer tippt, braucht keinen Mauszeiger im Bild — bewusst *jede* Taste und
    // nicht nur die belegten: auch eine unbelegte Taste ist Tastaturbedienung.
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      ref.read(pointerHiddenProvider.notifier).hide();
    }

    // KeyRepeatEvent is passed on so holding an arrow key keeps adjusting a
    // value; AppActionsNotifier decides which actions may repeat.
    if (event is KeyDownEvent) {
      return ref.read(appActionsProvider).handleKeyPress(event.logicalKey);
    }

    if (event is KeyRepeatEvent) {
      return ref
          .read(appActionsProvider)
          .handleKeyPress(event.logicalKey, isRepeat: true);
    }

    return KeyEventResult.ignored;
  }
}
