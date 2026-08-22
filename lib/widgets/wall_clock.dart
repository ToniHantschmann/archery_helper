import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/clock_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../providers/settings_provider.dart';

/// Die Wanduhr: baut seinen Inhalt mit der aktuellen Uhrzeit und stellt sich
/// dafür minütlich neu.
///
/// Der einzige Ort in der App, an dem die Uhrzeit tickt — die drei Anzeigen, die
/// sie zeigen, brauchen denselben Takt, aber nicht dasselbe Bild: auf der
/// LED-Wand steht die Uhrzeit allein und in eigener Geometrie. Was gebaut wird,
/// entscheidet deshalb der [builder]; dieses Widget weiß nur, *wann*.
/// Für die beiden Bildschirmanzeigen gibt es [WallClockFace].
///
/// Zeit aus [clock] statt aus `DateTime.now()`, wie in `PhaseClock`: so steuert
/// die Fake-Clock eines `testWidgets`-Laufs auch diese Anzeige.
class WallClock extends StatefulWidget {
  final Widget Function(BuildContext context, DateTime now) builder;

  const WallClock({super.key, required this.builder});

  @override
  State<WallClock> createState() => _WallClockState();
}

class _WallClockState extends State<WallClock> {
  late DateTime _now = clock.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Re-arms itself exactly on the next full minute instead of ticking every
  /// second: the display only shows hours and minutes, and a kiosk that
  /// repaints 60 times per minute for nothing is a kiosk that never lets the
  /// GPU idle.
  void _scheduleNextMinute() {
    final now = clock.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    _tick?.cancel();
    _tick = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() => _now = clock.now());
      _scheduleNextMinute();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// Uhrzeit und Datum, so groß wie der Platz hergibt.
///
/// Dasselbe Bild in der Ruheanzeige und im Wettkampf, und deshalb an einer
/// Stelle: es ist beide Male dieselbe Aussage — an dieser Anzeige läuft gerade
/// nichts, hier ist die Uhrzeit. Ohne eigenen Rand, den setzt der Aufrufer: die
/// Ruheanzeige hat den ganzen Schirm, der Wettkampf nur die Mitte zwischen
/// seinen Leisten.
class WallClockFace extends ConsumerWidget {
  const WallClockFace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return WallClock(
      builder: (context, now) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible, so the FittedBox is constrained in height as well: in a
          // Column a plain child is laid out unbounded, and scaleDown would
          // then only ever react to the width.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ClockTexts.formatClock(now),
                style: AppType.clockSmall,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ClockTexts.formatDate(now, language),
            style: AppType.display.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}
