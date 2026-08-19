import 'dart:convert';

import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/keyboard_config.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/settings_section.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/repositories/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    timeFormat: TimeFormat.seconds,
    language: AppLanguage.english,
    // Der Default ist true, also prüft nur false, dass der Wert wirklich
    // gespeichert und nicht bloß wieder auf den Default gesetzt wird.
    fullscreen: false,
    alternatingArrows: 5,
    timerScale: 1.15,
    competitionDiscipline: CompetitionDiscipline.outdoor,
    competitionEnds: 9,
    competitionLineup: CompetitionLineup.ab,
    // Bewusst der letzte Wert des Enums: ein Index, der beim Lesen aus dem
    // Gespeicherten am ehesten aus der Liste fällt.
    competitionDisplay: CompetitionDisplay.ledWithControl,
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
    expect(loaded.timeFormat, custom.timeFormat);
    expect(loaded.language, custom.language);
    expect(loaded.fullscreen, custom.fullscreen);
    expect(loaded.alternatingArrows, custom.alternatingArrows);
    expect(loaded.timerScale, custom.timerScale);
    expect(loaded.competitionDiscipline, custom.competitionDiscipline);
    expect(loaded.competitionEnds, custom.competitionEnds);
    expect(loaded.competitionLineup, custom.competitionLineup);
    expect(loaded.competitionDisplay, custom.competitionDisplay);
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
      'timeFormat',
      'language',
      'fullscreen',
      'alternatingArrows',
      'timerScale',
      'competitionDiscipline',
      'competitionEnds',
      'competitionLineup',
      'competitionDisplay',
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

    test('an out of range display index', () async {
      // Beide Enden: eine gespeicherte Anzeigeart, die es nicht mehr gibt, ist
      // der Fall, der beim Schrumpfen des Enums entsteht.
      for (final index in [-1, CompetitionDisplay.values.length]) {
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode({'competitionDisplay': index}),
        });

        final loaded = await repository.loadSettings();
        expect(loaded.competitionDisplay, CompetitionDisplay.standard);
      }
    });

    test('an anzeigegröße outside the allowed range', () async {
      for (final entry in {5.0: Settings.maxTimerScale, 0.0: Settings.minTimerScale}
          .entries) {
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode({'timerScale': entry.key}),
        });

        final loaded = await repository.loadSettings();
        expect(loaded.timerScale, entry.value);
      }
    });

    /// Ein glatter Faktor landet als `int` im JSON — ein `as double` würde
    /// daran scheitern und dabei die ganze gespeicherte Konfiguration
    /// verwerfen, nicht nur dieses Feld.
    test('a whole-number scale stored as int', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'timerScale': 1, 'volume': 0.25}),
      });

      final loaded = await repository.loadSettings();
      expect(loaded.timerScale, 1.0);
      expect(loaded.volume, 0.25, reason: 'der Rest überlebt es');
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

  /// Die Reset-Zeile eines Bereichs darf nur anfassen, was auf ihrem Screen
  /// steht — sonst nähme sie beim Zurücksetzen der Wettkampfwerte die
  /// Ampelzeiten mit. Jedes neue Feld muss in genau einem Bereich landen.
  group('resetting one section', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('the competition section takes its own fields and nothing else', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier
        ..setCompetitionDiscipline(CompetitionDiscipline.outdoor)
        ..setCompetitionLineup(CompetitionLineup.ab)
        ..setCompetitionDisplay(CompetitionDisplay.led)
        ..setAlternatingArrows(5);

      notifier.resetSection(SettingsSection.competition);

      const defaults = Settings();
      final settings = container.read(settingsProvider);

      expect(settings.competitionDiscipline, defaults.competitionDiscipline);
      expect(settings.competitionEnds, defaults.competitionEnds);
      expect(settings.competitionLineup, defaults.competitionLineup);
      expect(settings.competitionDisplay, defaults.competitionDisplay);
      expect(settings.alternatingArrows, 5, reason: 'gehört zur Ampel');
    });

    test('the timer section takes the display scale with it', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier
        ..setTimerScale(1.4)
        ..setCompetitionLineup(CompetitionLineup.ab);

      notifier.resetSection(SettingsSection.timer);

      final settings = container.read(settingsProvider);
      expect(settings.timerScale, const Settings().timerScale);
      expect(
        settings.competitionLineup,
        CompetitionLineup.ab,
        reason: 'gehört zum Wettkampf',
      );
    });
  });
}
