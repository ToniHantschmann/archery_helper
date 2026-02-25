import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';
import '../core/l10n/app_language.dart';
import '../providers/settings_provider.dart';
import '../providers/app_state_provider.dart';
import '../core/l10n/settings_texts.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    // Watch the localized texts provider
    final texts = ref.watch(settingsTextsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref
                .read(appStateProvider.notifier)
                .navigateToScreen(AppScreen.timer);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Section (NEU)
          _buildSectionHeader(texts.languageSection),
          _buildDropdownTile(
            title: texts.language,
            value: settings.language,
            items: AppLanguage.values,
            itemBuilder: (lang) => texts.getLanguageName(lang),
            onChanged: (lang) => settingsNotifier.setLanguage(lang),
          ),

          const Divider(height: 40),

          // Sound Settings Section
          _buildSectionHeader(texts.soundSection),
          _buildSwitchTile(
            title: texts.soundEnabled,
            value: settings.soundEnabled,
            onChanged: (value) => settingsNotifier.toggleSound(),
          ),
          _buildSliderTile(
            title: texts.volume,
            value: settings.volume,
            enabled: settings.soundEnabled,
            onChanged: (value) => settingsNotifier.setVolume(value),
            formatter: texts.formatPercentage,
          ),

          const Divider(height: 40),

          // Timer Settings Section
          _buildSectionHeader(texts.timerSection),
          _buildDropdownTile(
            title: texts.defaultMode,
            value: settings.defaultMode,
            items: TimerMode.values,
            itemBuilder: (mode) => texts.getModeName(mode),
            onChanged: (mode) => settingsNotifier.setDefaultMode(mode),
          ),
          _buildSwitchTile(
            title: texts.autoStart,
            subtitle: texts.autoStartSubtitle,
            value: settings.autoStart,
            onChanged: (value) => settingsNotifier.toggleAutoStart(),
          ),
          _buildSwitchTile(
            title: texts.showMilliseconds,
            value: settings.showMilliseconds,
            onChanged: (value) => settingsNotifier.toggleShowMilliseconds(),
          ),

          const Divider(height: 40),

          // Custom Timer Settings Section
          _buildSectionHeader(texts.customTimesSection),
          _buildDurationTile(
            title: texts.preparationTime,
            duration: settings.customPrepTime,
            onChanged:
                (duration) => settingsNotifier.setCustomPrepTime(duration),
            formatter: texts.formatDurationDisplay,
            unitShort: texts.secondsShort,
          ),
          _buildDurationTile(
            title: texts.mainTime,
            duration: settings.customMainTime,
            onChanged:
                (duration) => settingsNotifier.setCustomMainTime(duration),
            formatter: texts.formatDurationDisplay,
            unitShort: texts.secondsShort,
          ),

          const SizedBox(height: 40),

          // Reset Button
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showResetDialog(context, ref, settingsNotifier),
              icon: const Icon(Icons.restore),
              label: Text(texts.resetToDefaultsButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
    required String Function(double) formatter,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: formatter(value),
              activeColor: Colors.green,
            ),
            Text(
              formatter(value),
              style: TextStyle(color: enabled ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
          dropdownColor: Colors.grey[850],
          items:
              items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(itemBuilder(item)),
                );
              }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDurationTile({
    required String title,
    required Duration duration,
    required ValueChanged<Duration> onChanged,
    required String Function(Duration) formatter,
    required String unitShort,
  }) {
    final controller = TextEditingController(
      text: duration.inSeconds.toString(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(formatter(duration)),
        trailing: SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              suffixText: unitShort,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            onSubmitted: (value) {
              final seconds = int.tryParse(value);
              if (seconds != null && seconds >= 0) {
                onChanged(Duration(seconds: seconds));
              }
            },
          ),
        ),
      ),
    );
  }

  void _showResetDialog(
    BuildContext context,
    WidgetRef ref,
    SettingsNotifier notifier,
  ) {
    final texts = ref.read(settingsTextsProvider);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(texts.resetDialogTitle),
            content: Text(texts.resetDialogContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(texts.cancelButton),
              ),
              ElevatedButton(
                onPressed: () {
                  notifier.resetToDefaults();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(texts.settingsResetSnackbar),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(texts.resetButton),
              ),
            ],
          ),
    );
  }
}
