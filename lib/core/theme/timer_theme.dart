import 'package:flutter/material.dart';

import '../../models/timer_state.dart';
import 'app_palette.dart';

/// One state of the shooting signal.
///
/// There is no drawn traffic light any more — the signal is the colour of the
/// whole screen, so there is nothing here that lights up or glows. The three
/// signals keep their everyday meaning, which is also the World Archery
/// meaning: red = do not shoot, green = shooting time, amber = the end of the
/// shooting time is near.
enum TrafficSignal {
  red(AppPalette.redCore, AppPalette.redOnTint),
  amber(AppPalette.amberCore, AppPalette.amberOnTint),
  green(AppPalette.greenCore, AppPalette.greenOnTint);

  const TrafficSignal(this.core, this.onTint);

  /// The saturated signal colour. Only ever used to tint the background,
  /// never as a large flat fill.
  final Color core;

  /// The lighter version of the same hue, for type sitting on that tint.
  final Color onTint;
}

/// Maps timer state to the look of the timer screen.
///
/// Pure functions only: no widget, no ref. Everything here is exposed to the
/// UI through the providers in `lib/providers/ui_providers.dart`.
class TimerTheme {
  const TimerTheme._();

  /// Which signal a given state shows.
  ///
  /// Idle and ended both show red: in both cases nobody may shoot, and a
  /// screen with no signal at all would read as "display broken" from the
  /// shooting line.
  static TrafficSignal signalFor(TimerState state) {
    if (state.isInWarningPeriod) return TrafficSignal.amber;

    switch (state.phase) {
      case TimerPhase.idle:
      case TimerPhase.preparation:
      case TimerPhase.ended:
        return TrafficSignal.red;
      case TimerPhase.active:
        return TrafficSignal.green;
    }
  }

  /// Background of the timer screen.
  ///
  /// The tinted screen *is* the traffic light: it is the only thing carrying
  /// the signal, which is why the tint is much stronger than a decorative
  /// background would be. It stays a deep gradient rather than a flat block of
  /// signal colour, so the white countdown on top keeps its contrast.
  static LinearGradient backgroundGradient(TimerState state) {
    final tint = signalFor(state);
    final isIdle = state.phase == TimerPhase.idle;

    // Strong enough to read as red/green/amber across the tunnel, still dark
    // enough for white type. Idle is the exception: the signal is red, but the
    // room should not be bathed in red while nothing is happening, so idle
    // only hints at it.
    final strength = isIdle ? 0.08 : 0.34;

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
    if (state.isInWarningPeriod) return AppPalette.amberOnTint;
    if (state.isPaused) return AppPalette.textSecondary;
    if (state.phase == TimerPhase.ended) return AppPalette.redOnTint;
    return AppPalette.textPrimary;
  }

  /// Colour of the phase word above the countdown.
  ///
  /// Im Ampel-Modus ist das Wort nicht die Beschriftung einer Uhr, sondern
  /// füllt allein den Schirm. Es bleibt deshalb weiß: die Signalfarbe steht
  /// schon flächig dahinter, und ein rotes Wort auf rotem Grund verliert genau
  /// den Kontrast, von dem es auf die Distanz lebt.
  static Color phaseColor(TimerState state) {
    if (state.mode.isManual) return AppPalette.textOnSignal;
    if (state.phase == TimerPhase.idle) return AppPalette.textSecondary;
    return signalFor(state).onTint;
  }
}
