import 'package:flutter/material.dart';
import '../../models/timer_state.dart';

class TimerTheme {
  // Standard Farben für Timer-Phasen
  static const Map<TimerPhase, Color> _phaseColors = {
    TimerPhase.idle: Color(0xFF424242), // Grau
    TimerPhase.preparation: Color.fromRGBO(59, 13, 13, 1), // Orange
    TimerPhase.active: Color.fromARGB(255, 18, 74, 20), // Grün
    TimerPhase.ended: Color.fromRGBO(59, 13, 13, 1), // Dunkelgrau
  };

  static const Color warningColor = Color.fromARGB(255, 125, 84, 7); // Rot

  // Haupt-Methoden für UI-Mapping
  static Color getBackgroundColor(TimerState state) {
    if (state.isInWarningPeriod) {
      return warningColor;
    }
    return _phaseColors[state.phase] ?? const Color(0xFF424242);
  }

  static Color getTextColor(TimerState state) {
    return Colors.white; // Immer weiß für guten Kontrast
  }

  static double getFontSize(TimerState state) {
    return 120.0;
  }

  static FontWeight getFontWeight(TimerState state) {
    return FontWeight.bold;
  }
}
