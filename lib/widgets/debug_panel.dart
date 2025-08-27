import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';

class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DEBUG PANEL',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDebugRow('Phase', timerState.phase.name),
          _buildDebugRow('Mode', timerState.mode.name),
          _buildDebugRow('Running', '${timerState.isRunning}'),
          _buildDebugRow('Paused', '${timerState.isPaused}'),
          _buildDebugRow('Warning', '${timerState.isInWarningPeriod}'),
          _buildDebugRow('Remaining', '${timerState.remainingTime.inSeconds}s'),
          _buildDebugRow('Progress', '${(timerState.progress * 100).toInt()}%'),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
