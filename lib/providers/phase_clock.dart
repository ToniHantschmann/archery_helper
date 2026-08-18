import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Die Zeitrechnung einer ablaufenden Phase — geteilt von der Ampel
/// ([TimerNotifier]) und dem Wettkampfmodus ([CompetitionNotifier]).
///
/// Beide zählen Phasen herunter, die direkt aneinander hängen, und beide dürfen
/// dabei keine Zeit verlieren. Das ist nicht zweimal derselbe Code, weil es
/// zweimal dieselbe *Regel* ist: die Restzeit wird immer aus einem absoluten
/// Ende auf der Wanduhr abgeleitet, und ein Update wird genau auf den Moment
/// terminiert, in dem sich die angezeigte Zahl ändert.
///
/// Wer das Mixin benutzt, liefert vier Haken: [displayStep] und
/// [storedRemaining] als Fragen an den Zustand, [onRemainingChanged] und
/// [onPhaseElapsed] als die beiden Dinge, die passieren können.
mixin PhaseClock<T> on Notifier<T> {
  Timer? _timer;

  /// When the running phase ends, on the wall clock.
  ///
  /// The remaining time is always derived from this instead of being counted
  /// down step by step. A Timer is only a request: if the platform delivers a
  /// callback late — or drops it, which is what a busy or backgrounded browser
  /// tab does — then subtracting a fixed amount per callback makes the
  /// countdown lag behind real time, and a shot clock that runs slow is a shot
  /// clock that is wrong.
  ///
  /// `null` whenever nothing is ticking (idle, paused, ended).
  DateTime? _phaseEnd;

  /// The grid the shown number changes on: whole seconds, or tenths while the
  /// settings ask for milliseconds. The countdown is scheduled onto this grid
  /// (see [_scheduleNextStep]), so it is the update rate as well.
  ///
  /// Beide Uhren zeigen dieselbe Zahl auf demselben Raster, also steht die
  /// Regel hier statt zweimal daneben; überschreibbar bleibt sie für eine Uhr,
  /// die einmal ein eigenes Raster braucht.
  Duration get displayStep =>
      ref.read(showMillisecondsProvider)
          ? const Duration(milliseconds: 100)
          : const Duration(seconds: 1);

  /// Im [Notifier.build] aufzurufen: hält das Anzeigeraster live.
  ///
  /// Wird [displayStep] mitten im Lauf umgeschaltet, steht der armierte Timer
  /// noch auf der alten Kante — das nächste Update käme also zu spät oder zu
  /// früh. Ein sofortiger Schritt armiert auf dem neuen Raster neu.
  void watchDisplayStep() {
    ref.listen(showMillisecondsProvider, (previous, next) {
      if (previous != next && isTicking) stepNow();
    });
  }

  /// Die im Zustand hinterlegte Restzeit. Wird gebraucht, solange nichts läuft
  /// — dann gibt es kein Phasenende, von dem aus gerechnet werden könnte.
  Duration get storedRemaining;

  /// Eine neue anzuzeigende Restzeit. Der Nutzer des Mixins schreibt sie in
  /// seinen Zustand.
  void onRemainingChanged(Duration remaining);

  /// Die Phase ist abgelaufen. [anchor] ist ihr geplantes Ende, sofern die
  /// nächste Phase unmittelbar anschließt — siehe [startTicking].
  void onPhaseElapsed({DateTime? anchor});

  /// Ob gerade eine Phase auf der Uhr hängt.
  bool get isTicking => _phaseEnd != null;

  /// Das geplante Ende der laufenden Phase, oder `null`.
  DateTime? get phaseEnd => _phaseEnd;

  /// Anchors a phase of [duration] on the wall clock and arms the first update.
  ///
  /// [anchor] is the moment the phase conceptually starts. It is only passed
  /// when one phase follows another on its own: the callback that ends the
  /// preparation can arrive a few milliseconds late, and anchoring the main
  /// phase on the planned end instead of on "now" keeps that lateness from
  /// being added to the round. A skipped phase has no such anchor — there
  /// "now" is exactly right.
  void startTicking(Duration duration, {DateTime? anchor}) {
    _phaseEnd = (anchor ?? clock.now()).add(duration);
    _scheduleNextStep(remaining());
  }

  void stopTicking() {
    _timer?.cancel();
    _phaseEnd = null;
  }

  /// Time left in the running phase, straight off the clock.
  ///
  /// Deliberately not quantised: the update is already scheduled onto the
  /// display grid, and rounding the measured value onto that same grid is what
  /// used to let a late callback jump a step early. Falls back to
  /// [storedRemaining] when nothing is running.
  Duration remaining() {
    final end = _phaseEnd;
    if (end == null) return storedRemaining;

    final left = end.difference(clock.now());
    return left <= Duration.zero ? Duration.zero : left;
  }

  /// Rechnet sofort einen Schritt, statt auf den armierten Timer zu warten.
  ///
  /// Gebraucht, wenn sich das Anzeigeraster ([displayStep]) mitten im Lauf
  /// ändert: der nächste Timer steht dann noch auf der alten Kante.
  void stepNow() => _onStep();

  /// Arms a single timer for the exact moment the shown number changes.
  ///
  /// The countdown used to poll on a fixed 100ms grid and round the measured
  /// remainder onto the same grid — which is where the display changes too.
  /// A callback that arrived a few milliseconds late therefore rounded a whole
  /// step too far down and flipped the second early, leaving the next one on
  /// screen too long. Waiting for the boundary itself cannot make that error:
  /// a timer never fires *before* its deadline. And because the delay is
  /// recomputed from [_phaseEnd] at every step, lateness never accumulates.
  void _scheduleNextStep(Duration remaining) {
    _timer?.cancel();

    if (remaining <= Duration.zero) {
      onPhaseElapsed();
      return;
    }

    // The delay is always within (0, step] and never longer than [remaining],
    // so the timer cannot overshoot the end of the phase: once less than one
    // step is left it fires exactly on [_phaseEnd]. The phase therefore still
    // lasts exactly as long as it is configured for.
    final step = displayStep;
    final steps = (remaining.inMicroseconds / step.inMicroseconds).ceil();
    _timer = Timer(remaining - step * (steps - 1), _onStep);
  }

  void _onStep() {
    final left = remaining();

    if (left <= Duration.zero) {
      onPhaseElapsed(anchor: _phaseEnd);
      return;
    }

    onRemainingChanged(left);
    _scheduleNextStep(left);
  }
}
