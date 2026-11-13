import 'package:archery_helper/core/window/led_window.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was das Steuerfenster dem LED-Fenster schickt, muss dort genauso ankommen —
/// ein Feld, das unterwegs verloren geht, wäre ein falsches Bild auf der Wand.
void main() {
  test('a snapshot survives the trip into the LED window', () {
    const competition = CompetitionState(
      remainingTime: Duration(seconds: 87, milliseconds: 400),
      phase: TimerPhase.active,
      currentEnd: 4,
      totalEnds: 10,
      practiceEnds: 2,
      groupIndex: 1,
      lineup: CompetitionLineup.abcd,
      discipline: CompetitionDiscipline.outdoor,
      preparationTime: Duration(seconds: 10),
      shootingTime: Duration(seconds: 240),
      isRunning: true,
      isPaused: true,
      showClock: true,
      isCountingDown: true,
    );
    const settings = Settings(
      clubName: 'BSV',
      competitionDisplay: CompetitionDisplay.ledStretched,
    );

    final received = LedSnapshot.decode(
      const LedSnapshot(competition: competition, settings: settings).encode(),
    );

    expect(received.competition.toJson(), competition.toJson());
    expect(received.settings.toJson(), settings.toJson());
  });

  test('only the LED window recognises its arguments', () {
    expect(LedWindowArguments.tryDecode(''), isNull);
    expect(LedWindowArguments.tryDecode('{"type":"other"}'), isNull);
    expect(
      LedWindowArguments.tryDecode(
        const LedWindowArguments('7').encode(),
      )?.mainWindowId,
      '7',
    );
  });
}
