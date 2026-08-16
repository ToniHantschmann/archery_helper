import 'package:flutter/material.dart';

import '../../models/timer_state.dart';
import 'app_palette.dart';

/// One lamp of the traffic light.
///
/// The three signals keep their everyday meaning, which is also the World
/// Archery meaning: red = do not shoot, green = shooting time, amber = the end
/// of the shooting time is near.
enum TrafficLamp {
  red(AppPalette.redCore, AppPalette.redGlow, AppPalette.redOff),
  amber(AppPalette.amberCore, AppPalette.amberGlow, AppPalette.amberOff),
  green(AppPalette.greenCore, AppPalette.greenGlow, AppPalette.greenOff);

  const TrafficLamp(this.core, this.glow, this.off);

  /// Colour of the lit lamp.
  final Color core;

  /// Colour of the bloom around a lit lamp.
  final Color glow;

  /// Colour of the unlit socket — a very dark version of the same hue, so the
  /// housing still reads as a traffic light when the lamp is dark.
  final Color off;
}

/// Maps timer state to the look of the timer screen.
///
/// Pure functions only: no widget, no ref. Everything here is exposed to the
/// UI through the providers in `lib/providers/ui_providers.dart`.
class TimerTheme {
  const TimerTheme._();

  /// Which lamp is lit for a given state.
  ///
  /// Idle and ended both show red: in both cases nobody may shoot, and a
  /// traffic light that is completely dark would read as "display broken"
  /// from the shooting line.
  static TrafficLamp lampFor(TimerState state) {
    if (state.isInWarningPeriod) return TrafficLamp.amber;

    switch (state.phase) {
      case TimerPhase.idle:
      case TimerPhase.preparation:
      case TimerPhase.ended:
        return TrafficLamp.red;
      case TimerPhase.active:
        return TrafficLamp.green;
    }
  }

  /// The colour that carries the state through the rest of the screen:
  /// countdown digits, phase label, progress rail.
  static Color accentColor(TimerState state) => lampFor(state).core;

  /// Background of the timer screen.
  ///
  /// The whole screen stays tinted by the current phase — that is what lets
  /// somebody read the state from the corner of their eye — but the tint is a
  /// deep, desaturated gradient rather than a flat block of colour, so the
  /// white countdown keeps its contrast.
  static LinearGradient backgroundGradient(TimerState state) {
    final tint = lampFor(state);
    final isIdle = state.phase == TimerPhase.idle;

    // Enough tint to recognise the state from the corner of the eye, not
    // enough to turn the panel into a coloured surface — the lamp, the phase
    // word and the progress rail carry the colour, the background only hints
    // at it. Idle is the most neutral state of all: the light is red, but the
    // room should not be bathed in red while nothing is happening.
    final strength = isIdle ? 0.07 : 0.15;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(AppPalette.base, tint.core, strength * 0.55)!,
        Color.lerp(AppPalette.base, tint.core, strength)!,
        Color.lerp(AppPalette.abyss, tint.core, strength * 0.35)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  /// Countdown colour. White while there is time left, the signal colour once
  /// the state is one you must react to — a paused or warning clock should be
  /// distinguishable without reading the label.
  static Color timeColor(TimerState state) {
    if (state.isInWarningPeriod) return AppPalette.amberGlow;
    if (state.isPaused) return AppPalette.textSecondary;
    if (state.phase == TimerPhase.ended) return AppPalette.redGlow;
    return AppPalette.textPrimary;
  }

  /// Colour of the phase word above the countdown.
  static Color phaseColor(TimerState state) {
    if (state.phase == TimerPhase.idle) return AppPalette.textSecondary;
    return lampFor(state).glow;
  }

  /// How much of the current phase is left, from 1.0 down to 0.0.
  ///
  /// Quantised to whole seconds on purpose. The countdown ticks every 100ms,
  /// and a value that changed on every tick would repaint the progress rail
  /// ten times a second for a difference nobody can see from five meters.
  static double phaseProgress(TimerState state) {
    final total = switch (state.phase) {
      TimerPhase.preparation => state.preparationTime,
      TimerPhase.active => state.mainTime,
      TimerPhase.idle => state.mainTime,
      TimerPhase.ended => state.mainTime,
    };

    if (state.phase == TimerPhase.idle) return 1.0;
    if (state.phase == TimerPhase.ended) return 0.0;
    if (total.inMilliseconds <= 0) return 0.0;

    final remainingSeconds = (state.remainingTime.inMilliseconds / 1000).ceil();
    final totalSeconds = (total.inMilliseconds / 1000).ceil();

    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }
}
