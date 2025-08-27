import 'package:flutter/material.dart';
import '../../models/timer_state.dart';

class TimerTheme {
  // Standard Farben für Timer-Phasen
  static const Map<TimerPhase, Color> _phaseColors = {
    TimerPhase.idle: Color(0xFF424242), // Grau
    TimerPhase.preparation: Color(0xFFFF9800), // Orange
    TimerPhase.active: Color(0xFF4CAF50), // Grün
    TimerPhase.ended: Color(0xFF212121), // Dunkelgrau
  };

  static const Color warningColor = Color(0xFFF44336); // Rot

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
    return state.isInWarningPeriod ? 140.0 : 120.0;
  }

  static FontWeight getFontWeight(TimerState state) {
    return state.isInWarningPeriod ? FontWeight.bold : FontWeight.normal;
  }

  // Zusätzliche Theme-Optionen (für später)
  static Color getAccentColor(TimerState state) {
    return state.isInWarningPeriod ? Colors.redAccent : Colors.greenAccent;
  }
}
