import 'dart:convert';

import 'package:archery_helper/core/audio/signal_tone.dart';
import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/keyboard_config.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/settings_section.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/repositories/keyboard_config_repository.dart';
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
    signalTone: SignalTone.tone2,
    defaultMode: TimerMode.alternating,
    customPrepTime: Duration(seconds: 7),
    customMainTime: Duration(seconds: 45),
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
    competitionPracticeEnds: 2,
    competitionLineup: CompetitionLineup.ab,
    // Bewusst der letzte Wert des Enums: ein Index, der beim Lesen aus dem
    // Gespeicherten am ehesten aus der Liste fällt.
    competitionDisplay: CompetitionDisplay.ledStretched,
    competitionLedBrightness: 40,
    competitionCountdownTime: Duration(seconds: 90),
    competitionCountdownAutoStart: true,
    // Mit Umlaut: gespeichert wird JSON, und das muss ihn unverändert
    // zurückgeben.
    clubName: 'SV Münchenstein',
  );

  test('saved settings survive a round trip unchanged', () async {
    await repository.saveSettings(custom);
    final loaded = await repository.loadSettings();

    expect(loaded.soundEnabled, custom.soundEnabled);
    expect(loaded.volume, custom.volume);
    expect(loaded.signalTone, custom.signalTone);
    expect(loaded.defaultMode, custom.defaultMode);
    expect(loaded.customPrepTime, custom.customPrepTime);
    expect(loaded.customMainTime, custom.customMainTime);
    expect(loaded.showMilliseconds, custom.showMilliseconds);
    expect(loaded.timeFormat, custom.timeFormat);
    expect(loaded.language, custom.language);
    expect(loaded.fullscreen, custom.fullscreen);
    expect(loaded.alternatingArrows, custom.alternatingArrows);
    expect(loaded.timerScale, custom.timerScale);
    expect(loaded.competitionDiscipline, custom.competitionDiscipline);
    expect(loaded.competitionEnds, custom.competitionEnds);
    expect(loaded.competitionPracticeEnds, custom.competitionPracticeEnds);
    expect(loaded.competitionLineup, custom.competitionLineup);
    expect(loaded.competitionDisplay, custom.competitionDisplay);
    expect(loaded.competitionLedBrightness, custom.competitionLedBrightness);
    expect(loaded.competitionCountdownTime, custom.competitionCountdownTime);
    expect(
      loaded.competitionCountdownAutoStart,
      custom.competitionCountdownAutoStart,
    );
    expect(loaded.clubName, custom.clubName);
  });

  test('every field is written to the stored json', () {
    // Catches a field that toJson forgets even if fromJson defaults it back
    // to the same value the test happened to use.
    expect(custom.toJson().keys.toSet(), const {
      'soundEnabled',
      'volume',
      'signalTone',
      'defaultMode',
      'customPrepTime',
      'customMainTime',
      'showMilliseconds',
      'timeFormat',
      'language',
      'fullscreen',
      'alternatingArrows',
      'timerScale',
      'competitionDiscipline',
      'competitionEnds',
      'competitionPracticeEnds',
      'competitionLineup',
      'competitionDisplay',
      'competitionLedBrightness',
      'competitionCountdownTime',
      'competitionCountdownAutoStart',
      'clubName',
    });
  });

  test('the league survives a restart, and the old indices stay put', () async {
    // Die Disziplin wird als Index gespeichert: die Liga steht hinten, damit
    // eine gespeicherte Halle oder Freiluft nach dem Update dieselbe bleibt.
    expect(CompetitionDiscipline.indoor.index, 0);
    expect(CompetitionDiscipline.outdoor.index, 1);

    await repository.saveSettings(
      const Settings(competitionDiscipline: CompetitionDiscipline.league),
    );
    final loaded = await repository.loadSettings();
    expect(loaded.competitionDiscipline, CompetitionDiscipline.league);
  });

  group('falling back to defaults', () {
    test('nothing stored yet', () async {
      final loaded = await repository.loadSettings();
      expect(loaded.defaultMode, const Settings().defaultMode);
      expect(loaded.volume, const Settings().volume);
      // Eine Konfiguration von vor der zweiten Tonvariante kennt den Schlüssel
      // nicht und muss beim bisherigen Ton bleiben.
      expect(loaded.signalTone, SignalTone.tone1);
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

    test('a practice end count outside the allowed range', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({'competitionPracticeEnds': 12}),
      });

      final loaded = await repository.loadSettings();
      expect(
        loaded.competitionPracticeEnds,
        Settings.maxCompetitionPracticeEnds,
      );
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
      for (final entry in {
        5.0: Settings.maxTimerScale,
        0.0: Settings.minTimerScale,
      }.entries) {
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

    test('an LED brightness outside the allowed range', () async {
      for (final entry in {
        0: Settings.minLedBrightness,
        250: Settings.maxLedBrightness,
        // Als Kommazahl gespeichert darf sie nicht die Konfiguration kosten.
        60.0: 60,
      }.entries) {
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode({'competitionLedBrightness': entry.key}),
        });

        final loaded = await repository.loadSettings();
        expect(loaded.competitionLedBrightness, entry.value);
      }
    });

    test('a club name that is not a string, padded or too long', () async {
      final tooLong = 'X' * (Settings.maxClubNameLength + 10);

      for (final entry in <Object?, String>{
        42: '',
        null: '',
        '  TSV Dachau  ': 'TSV Dachau',
        tooLong: 'X' * Settings.maxClubNameLength,
      }.entries) {
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode({'clubName': entry.key, 'fullscreen': false}),
        });

        final loaded = await repository.loadSettings();
        expect(loaded.clubName, entry.value);
        expect(
          loaded.fullscreen,
          isFalse,
          reason: 'ein kaputter Name kostet nicht die übrigen Einstellungen',
        );
      }
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

  group('the stored extra keys', () {
    test('survive a round trip in their order', () {
      final (withFive, _) = const KeyboardConfig().withExtraKey(
        LogicalKeyboardKey.numpad5,
        AppAction.next,
      );
      final (config, _) = withFive.withExtraKey(
        LogicalKeyboardKey.numpad0,
        AppAction.next,
      );

      final loaded = KeyboardConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );

      expect(loaded.extraKeysFor(AppAction.next), [
        LogicalKeyboardKey.numpad5,
        LogicalKeyboardKey.numpad0,
      ]);
    });

    /// Die Standardbelegung steht im Code. Wird eine gespeicherte Zusatztaste
    /// später Standard, gewinnt der Standard — als Zusatz wäre sie nur noch
    /// eine Kappe an der falschen Zeile.
    test('drop a key that is a default key by now', () {
      final loaded = KeyboardConfig.fromJson({
        LogicalKeyboardKey.keyR.keyId.toString(): AppAction.next.name,
        LogicalKeyboardKey.numpad1.keyId.toString(): 'noSuchAction',
        LogicalKeyboardKey.numpad2.keyId.toString(): AppAction.back.name,
      });

      expect(loaded.extraBindings, {
        LogicalKeyboardKey.numpad2: AppAction.back,
      });
      expect(loaded.getAction(LogicalKeyboardKey.keyR), AppAction.resetTimer);
    });

    test('come back from the repository', () async {
      final keyboard = KeyboardConfigRepository();
      final (config, _) = const KeyboardConfig().withExtraKey(
        LogicalKeyboardKey.numpad8,
        AppAction.navigateUp,
      );

      await keyboard.saveConfig(config);
      final loaded = await keyboard.loadConfig();

      expect(
        loaded.getAction(LogicalKeyboardKey.numpad8),
        AppAction.navigateUp,
      );
    });

    /// Die frühere, vollständig gespeicherte Belegung enthielt nur alte
    /// Standardwerte. Aus ihr wird nichts übernommen.
    test('ignore the old full config', () async {
      SharedPreferences.setMockInitialValues({
        'keyboard_config': jsonEncode({
          LogicalKeyboardKey.keyB.keyId.toString(): AppAction.previous.name,
        }),
        'keyboard_config_version': 2,
      });

      final loaded = await KeyboardConfigRepository().loadConfig();

      expect(loaded.extraBindings, isEmpty);
    });

    test('fall back to none on corrupt data', () async {
      SharedPreferences.setMockInitialValues({
        'keyboard_extra_keys': '{not json',
      });

      final loaded = await KeyboardConfigRepository().loadConfig();

      expect(loaded.extraBindings, isEmpty);
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
        ..setCompetitionLedBrightness(30)
        ..setCompetitionPracticeEnds(0)
        ..setCompetitionCountdownTime(const Duration(seconds: 30))
        ..toggleCompetitionCountdownAutoStart()
        ..setAlternatingArrows(5);

      notifier.resetSection(SettingsSection.competition);

      const defaults = Settings();
      final settings = container.read(settingsProvider);

      expect(settings.competitionDiscipline, defaults.competitionDiscipline);
      expect(settings.competitionEnds, defaults.competitionEnds);
      expect(
        settings.competitionPracticeEnds,
        defaults.competitionPracticeEnds,
      );
      expect(settings.competitionLineup, defaults.competitionLineup);
      expect(settings.competitionDisplay, defaults.competitionDisplay);
      expect(
        settings.competitionLedBrightness,
        defaults.competitionLedBrightness,
      );
      expect(
        settings.competitionCountdownTime,
        defaults.competitionCountdownTime,
      );
      expect(
        settings.competitionCountdownAutoStart,
        defaults.competitionCountdownAutoStart,
      );
      expect(settings.alternatingArrows, 5, reason: 'gehört zur Ampel');
    });

    test('the general section clears the club name', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier
        ..setClubName('TSV Dachau')
        ..setCompetitionLineup(CompetitionLineup.ab);

      notifier.resetSection(SettingsSection.general);

      final settings = container.read(settingsProvider);
      expect(settings.clubName, isEmpty);
      expect(
        settings.competitionLineup,
        CompetitionLineup.ab,
        reason: 'gehört zum Wettkampf',
      );
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
