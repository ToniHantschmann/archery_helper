import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/timer_theme.dart';

/// The traffic light itself: a housing with three lamps, one of them lit.
///
/// Drawn with a [CustomPainter] rather than assembled from decorated boxes, so
/// a lamp can have a real lens gradient, a bloom around it and a specular
/// highlight — that is what makes it read as a lamp instead of a coloured dot
/// from the far end of the tunnel.
///
/// The lamp change is the only animation: a short crossfade so a phase change
/// is noticeable, then nothing moves. Loops or pulses are deliberately absent —
/// this display hangs in the field of view of somebody at full draw.
class TrafficLight extends StatelessWidget {
  final TrafficLamp lit;
  final Axis axis;

  const TrafficLight({super.key, required this.lit, this.axis = Axis.vertical});

  /// Housing proportions, expressed in lamp diameters.
  static const double _gapFactor = 0.18;
  static const double _padFactor = 0.24;

  /// Width of the housing border. A `BoxDecoration` border is laid out as
  /// padding, so it has to come off the available space before the lamp
  /// diameter is derived — forgetting it costs exactly `2 * _border` pixels of
  /// overflow on a window that is tight to begin with.
  static const double _border = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = axis == Axis.vertical;

        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final maxHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 760.0;

        final along = (vertical ? maxHeight : maxWidth) - 2 * _border;
        final across = (vertical ? maxWidth : maxHeight) - 2 * _border;

        // along = 3d + 2*gap + 2*pad, across = d + 2*pad
        final alongFactor = 3 + 2 * _gapFactor + 2 * _padFactor;
        final acrossFactor = 1 + 2 * _padFactor;

        // The half pixel is slack, not superstition: the housing padding is
        // derived from the diameter, and a diameter that fits its box exactly
        // turns any rounding into a visible overflow stripe.
        final diameter = math
            .min(
              (along - 0.5) / alongFactor,
              (across - 0.5) / acrossFactor,
            )
            .clamp(16.0, 300.0);
        final gap = diameter * _gapFactor;
        final pad = diameter * _padFactor;

        final lamps = <Widget>[];
        for (final lamp in TrafficLamp.values) {
          if (lamps.isNotEmpty) {
            lamps.add(SizedBox(width: gap, height: gap));
          }
          lamps.add(
            _Lamp(lamp: lamp, isLit: lamp == lit, diameter: diameter),
          );
        }

        final radius = BorderRadius.circular(diameter * 0.42);

        return Center(
          // The halo sits on its own box on purpose. It has to animate with
          // the lamp change, and an AnimatedContainer that also carried the
          // padding would interpolate the layout: for a few frames the housing
          // would be padded for the previous size while the lamps already have
          // the new one — which is exactly how you get a four pixel overflow
          // stripe on a smaller window.
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                // Ambient depth ...
                const BoxShadow(
                  color: Color(0xCC010306),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
                // ... plus a halo in the colour of the lit lamp, so the housing
                // participates in the signal instead of sitting on top of it.
                BoxShadow(
                  color: lit.core.withValues(alpha: 0.28),
                  blurRadius: 70,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.surfaceRaised, Color(0xFF0C131E)],
                ),
                borderRadius: radius,
                border: Border.all(color: AppPalette.outline, width: _border),
              ),
              child: Flex(
                direction: axis,
                mainAxisSize: MainAxisSize.min,
                children: lamps,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Lamp extends StatelessWidget {
  final TrafficLamp lamp;
  final bool isLit;
  final double diameter;

  const _Lamp({
    required this.lamp,
    required this.isLit,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isLit ? 1.0 : 0.0),
      duration: AppMotion.medium,
      curve: AppMotion.curve,
      builder: (context, intensity, _) {
        return CustomPaint(
          size: Size.square(diameter),
          painter: _LampPainter(lamp: lamp, intensity: intensity),
          isComplex: true,
        );
      },
    );
  }
}

class _LampPainter extends CustomPainter {
  final TrafficLamp lamp;

  /// 0 = dark socket, 1 = fully lit.
  final double intensity;

  const _LampPainter({required this.lamp, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    if (radius <= 0) return;

    // ── Socket: always painted, so an unlit lamp is a dark lens and not a
    //    hole in the housing. ──
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 0.95,
          colors: [
            Color.lerp(lamp.off, Colors.white, 0.07)!,
            lamp.off,
            const Color(0xFF010306),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    if (intensity > 0.01) {
      // The whole lit state is drawn into one layer and faded as a unit, so
      // the crossfade between two lamps cannot show a half-drawn lens.
      canvas.saveLayer(
        rect.inflate(radius),
        Paint()..color = Colors.white.withValues(alpha: intensity.clamp(0, 1)),
      );

      // Bloom around the lens.
      canvas.drawCircle(
        center,
        radius * 0.9,
        Paint()
          ..color = lamp.glow.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5),
      );

      // Lens.
      canvas.drawCircle(
        center,
        radius * 0.93,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.28, -0.4),
            radius: 1.0,
            colors: [
              Color.lerp(lamp.core, Colors.white, 0.7)!,
              lamp.core,
              Color.lerp(lamp.core, Colors.black, 0.42)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect),
      );

      // Specular highlight — the detail that makes it look like glass.
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(-radius * 0.3, -radius * 0.42),
          width: radius * 0.72,
          height: radius * 0.44,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.14),
      );

      canvas.restore();
    }

    // Rim, picking up a little of the lamp colour while lit.
    canvas.drawCircle(
      center,
      radius - radius * 0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..color = Color.lerp(
          AppPalette.outline,
          lamp.glow,
          0.35 * intensity,
        )!.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_LampPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.lamp != lamp;
  }
}
