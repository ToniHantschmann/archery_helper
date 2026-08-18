import 'dart:convert';

import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/keyboard_config.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/repositories/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// toJson/fromJson are hand written, so a newly added setting is easy to
/// forget on one of the two sides — the user would silently lose it on the
/// next app start. The round trip below guards against that.
void main() {
  const storageKey = 'app_settings';

  late SettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
  });

  /// Every field differs from its default, so a field dropped in toJson or
  /// fromJson shows up as a mismatch instead of accidentally matching.
  const custom = Settings(
    soundEnabled: false,
    volume: 0.35,
    defaultMode: TimerMode.alternating,
    customPrepTime: Duration(seconds: 7),
    customMainTime: Duration(seconds: 45),
    autoStart: true,
    showMilliseconds: true,
    language: AppLanguage.english,
    alternatingArrows: 5,
    competitionDiscipline: CompetitionDiscipline.outdoor,
    competitionEnds: 9,
    competitionLineup: CompetitionLineup.ab,
  );

  test('saved settings survive a round trip unchanged', () async {
    await repository.saveSettings(custom);
    final loaded = await repository.loadSettings();

    expect(loaded.soundEnabled, custom.soundEnabled);
    expect(loaded.volume, custom.volume);
    expect(loaded.defaultMode, custom.defaultMode);
    expect(loaded.customPrepTime, custom.customPrepTime);
    expect(loaded.customMainTime, custom.customMainTime);
    expect(loaded.autoStart, custom.autoStart);
    expect(loaded.showMilliseconds, custom.showMilliseconds);
    expect(loaded.language, custom.language);
    expect(loaded.alternatingArrows, custom.alternatingArrows);
    expect(loaded.competitionDiscipline, custom.competitionDiscipline);
    expect(loaded.competitionEnds, custom.competitionEnds);
    expect(loaded.competitionLineup, custom.competitionLineup);
  });

  test('every field is written to the stored json', () {
    // Catches a field that toJson forgets even if fromJson defaults it back
    // to the same value the test happened to use.
    expect(custom.toJson().keys.toSet(), const {
      'soundEnabled',
      'volume',
      'defaultMode',
      'customPrepTime',
      'customMainTime',
      'autoStart',
      'showMilliseconds',
      'language',
      'alternatingArrows',
      'competitionDiscipline',
      'competitionEnds',
      'competitionLineup',
    });
  });

  group('falling back to defaults', () {
    test('nothing stored yet', () async {
      final loaded = await repository.loadSettings();
      expect(loaded.defaultMode, const Settings().defaultMode);
      expect(loaded.volume, const Settings().volume);
    });

    test('unreadable json', () async {
      SharedPreferences.setMockInitialValues({storageKey: 'not json at all'});

      final loaded = await repository.loadSettings();
      expect(loaded.language, const Settings().language);
      expect(loaded.customMainTime, const Settings().customMainTime);
    });

    test('json written by an older version misses keys', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'volume': 0.25}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.volume, 0.25, reason: 'known keys are still used');
      expect(loaded.defaultMode, const Settings().defaultMode);
      expect(loaded.language, const Settings().language);
      expect(loaded.alternatingArrows, const Settings().alternatingArrows);
    });

    test('an arrow count outside the allowed range', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'alternatingArrows': 99}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.alternatingArrows, Settings.maxAlternatingArrows);
    });

    test('an end count outside the allowed range', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'competitionEnds': 0}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.competitionEnds, Settings.minCompetitionEnds);
    });

    test('an out of range lineup index', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'competitionLineup': 42}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.competitionLineup, CompetitionLineup.abcd);
    });

    test('an out of range mode index', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'defaultMode': 99}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.defaultMode, TimerMode.indoor);
    });
  });

  test('clearing removes the stored settings', () async {
    await repository.saveSettings(custom);
    await repository.clearSettings();

    final loaded = await repository.loadSettings();
    expect(loaded.defaultMode, const Settings().defaultMode);
  });

  group('a stored keyboard config', () {
    /// Eine gespeicherte Belegung kennt nur, was es zur Zeit des Speicherns
    /// gab. Eine später hinzugekommene Aktion wäre ohne Ergänzung dauerhaft
    /// ohne Taste — erreichbar nur noch über die Maus.
    test('gets the default key of an action it cannot know', () {
      final old = KeyboardConfig(
        keyBindings: {LogicalKeyboardKey.space: AppAction.next},
      );

      final loaded = KeyboardConfig.fromJson(old.toJson());

      expect(loaded.getAction(LogicalKeyboardKey.space), AppAction.next);
      expect(
        loaded.getAction(LogicalKeyboardKey.backspace),
        AppAction.previous,
      );
      expect(loaded.getAction(LogicalKeyboardKey.delete), AppAction.forward);
    });

    test('keeps a remapped key instead of restoring its default', () {
      final remapped = KeyboardConfig.defaults()
          .removeKeyBinding(LogicalKeyboardKey.backspace)
          .addKeyBinding(LogicalKeyboardKey.keyB, AppAction.previous);

      final loaded = KeyboardConfig.fromJson(remapped.toJson());

      expect(loaded.getAction(LogicalKeyboardKey.keyB), AppAction.previous);
      expect(
        loaded.getAction(LogicalKeyboardKey.backspace),
        isNull,
        reason: 'the action already has a key, so its default stays free',
      );
    });
  });
}
