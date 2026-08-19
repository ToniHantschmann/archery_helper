import 'signal_state.dart';
import 'timer_state.dart';

/// Die Disziplin bestimmt, wie eine Passe aussieht.
///
/// Halle und Freiluft unterscheiden sich in der Qualifikation nur in Pfeilzahl
/// und Schusszeit — deshalb ist das *eine* Einstellung und nicht drei. Die
/// Passenzahl hängt mit dran, bleibt danach aber frei änderbar (ein Vereins-
/// wettkampf schießt auch mal zehn Passen).
enum CompetitionDiscipline {
  indoor(arrowsPerEnd: 3, shootingTime: Duration(seconds: 120), defaultEnds: 20),
  outdoor(
    arrowsPerEnd: 6,
    shootingTime: Duration(seconds: 240),
    defaultEnds: 12,
  );

  const CompetitionDiscipline({
    required this.arrowsPerEnd,
    required this.shootingTime,
    required this.defaultEnds,
  });

  /// Wie viele Pfeile eine Gruppe pro Passe schießt.
  final int arrowsPerEnd;

  /// Wie lange sie dafür Zeit hat.
  final Duration shootingTime;

  final int defaultEnds;
}

/// Wie die Schützen an der Scheibe aufgeteilt sind.
///
/// Vier Schützen pro Scheibe schießen in zwei Gruppen (AB, dann CD), zwei
/// Schützen einzeln (A, dann B), und wenn jeder seine eigene Scheibe hat,
/// schießen alle zusammen.
enum CompetitionLineup {
  abcd(['AB', 'CD']),
  ab(['A', 'B']),
  single(['A']);

  const CompetitionLineup(this.groupLabels);

  /// Die Gruppen in Grundreihenfolge. Bewusst sprachneutral — A bis D heißen
  /// in jeder Sprache gleich.
  final List<String> groupLabels;

  /// Die Gruppen in Schussreihenfolge — die einzige Stelle, die weiß, was
  /// „umgekehrt" konkret heißt.
  ///
  /// Steht hier und nicht nur auf [CompetitionState], weil die Gruppenleiste
  /// dieselbe Reihenfolge braucht, ihren Zustand aber nicht am Sekundentakt
  /// hängen haben darf (siehe `competitionGroupRailProvider`) und deshalb nur
  /// [CompetitionState.isOrderReversed] gereicht bekommt.
  List<String> orderedLabels({required bool reversed}) =>
      reversed ? groupLabels.reversed.toList() : groupLabels;
}

/// Auf welchem Schirm der Wettkampfmodus angezeigt wird.
///
/// Am Außenstand hängt eine LED-Wand mit 96×64 cm bei 5 mm Pixelabstand, also
/// **192×128 Pixel**. Darauf passt der normale Wettkampfschirm nicht — dort
/// bleibt nur Restzeit, Gruppe und Ampelfarbe, und der Hintergrund muss
/// schwarz sein, damit die Dioden an diesen Stellen einfach aus bleiben.
///
/// Das ist eine Eigenschaft des *Aufstellungsorts*, nicht der Runde: der
/// Rechner am Außenstand steht dauerhaft auf [led], der im Tunnel auf
/// [standard]. Deshalb eine persistierte Einstellung und keine Taste.
enum CompetitionDisplay {
  /// Der volle Wettkampfschirm auf einem gewöhnlichen Monitor.
  standard,

  /// Das 192×128-Panel, ganzzahlig hochskaliert auf das Fenster. Ohne diesen
  /// Zwischenschritt wäre das Layout auf einem normalen Bildschirm ein
  /// briefmarkengroßer Fleck und nur über Tests zu beurteilen.
  ledPreview,

  /// Das Panel in echten Gerätepixeln, links oben, Rest des Bildes schwarz.
  led,

  /// Das Panel links oben *in* der vollen Bedienansicht.
  ///
  /// Für den Turnierbetrieb, mit **gespiegelten** Bildschirmen: der Player
  /// sieht nur das Rechteck (0, 0, 192, 128) des Bildes, alles daneben existiert
  /// für die Wand nicht. Also kann dort dieselbe Ansicht stehen, die der
  /// Schießleiter am Laptop ohnehin braucht — Passe, Gruppen und Tastenleiste,
  /// die [led] gerade wegnimmt.
  ///
  /// Ein Fenster, eine Uhr, keine Fensterverwaltung: die Wand hängt nicht daran,
  /// wie das Layout daneben aussieht, sondern nur daran, dass das Panel zuletzt
  /// und auf Gerätepixel (0,0) gezeichnet wird.
  ledWithControl,
}

/// Vorbereitungszeit vor jeder Schusszeit — am Passenanfang und beim
/// Gruppenwechsel derselbe Wert (World Archery: 10 Sekunden).
const competitionPreparationTime = Duration(seconds: 10);

/// Ab wann die Restzeit als knapp gilt (Gelb). Fest, weil die Regel fest ist:
/// die letzten 30 Sekunden einer Passe.
const competitionWarningThreshold = Duration(seconds: 30);

/// Der Stand einer Qualifikationsrunde.
///
/// Teilt [TimerPhase] mit der Ampel — `preparation` ist rot, `active` ist die
/// Schusszeit. Was hier dazukommt, ist die Runde drumherum: die wievielte Passe
/// läuft, und welche Gruppe von wie vielen gerade dran ist.
class CompetitionState {
  final Duration remainingTime;
  final TimerPhase phase;

  /// Die laufende Passe, ab 1 gezählt.
  final int currentEnd;

  final int totalEnds;

  /// Welche Gruppe der Passe gerade dran ist — Index in [groupOrder].
  final int groupIndex;

  final CompetitionLineup lineup;
  final CompetitionDiscipline discipline;

  final Duration preparationTime;
  final Duration shootingTime;
  final Duration warningThreshold;

  final bool isRunning;
  final bool isPaused;

  const CompetitionState({
    required this.remainingTime,
    required this.phase,
    required this.totalEnds,
    required this.lineup,
    required this.discipline,
    required this.preparationTime,
    required this.shootingTime,
    this.currentEnd = 1,
    this.groupIndex = 0,
    this.warningThreshold = competitionWarningThreshold,
    this.isRunning = false,
    this.isPaused = false,
  });

  /// Ob die Gruppen dieser Passe in umgekehrter Reihenfolge schießen.
  ///
  /// Regel: nach jeder Passe beginnt die andere Gruppe — Passe 1 AB/CD,
  /// Passe 2 CD/AB, Passe 3 wieder AB/CD. Über die ganze Runde kommt so jede
  /// Gruppe gleich oft zuerst dran.
  bool get isOrderReversed => currentEnd.isEven;

  /// Die Gruppen dieser Passe in Schussreihenfolge.
  List<String> get groupOrder =>
      lineup.orderedLabels(reversed: isOrderReversed);

  String get currentGroup => groupOrder[groupIndex];

  String? get nextGroup =>
      hasNextGroup ? groupOrder[groupIndex + 1] : null;

  /// Ob in dieser Passe nach der laufenden Gruppe noch eine folgt.
  bool get hasNextGroup => groupIndex + 1 < groupOrder.length;

  bool get hasNextEnd => currentEnd < totalEnds;

  /// Ob in dieser Passe vor der laufenden Gruppe schon eine dran war.
  bool get hasPreviousGroup => groupIndex > 0;

  bool get hasPreviousEnd => currentEnd > 1;

  /// Ob die laufende Vorbereitungszeit ein Gruppenwechsel ist und nicht der
  /// Anfang einer Passe. Derselbe Zeitwert, andere Ansage.
  bool get isChangeover => groupIndex > 0;

  /// Ob die Runde zwischen zwei Passen auf das Startsignal wartet.
  ///
  /// Derselbe Zustand wie vor der ersten Passe — `idle` heißt immer „wartet auf
  /// den Schießleiter". Dass es hier ums Pfeileholen geht und nicht um den
  /// Rundenstart, steht allein daran, wo in der Runde gewartet wird: nicht in
  /// der ersten Passe, und am Anfang einer Passe und nicht mitten drin. Ein
  /// eigenes Feld dafür wäre eine zweite Darstellung derselben Tatsache.
  ///
  /// Vor einem zurückgespulten Gruppenwechsel wartet die Runde ebenfalls, aber
  /// die Pfeile stecken noch in der Scheibe — deshalb der Blick auf
  /// [groupIndex].
  bool get isWaitingBetweenEnds =>
      phase == TimerPhase.idle && currentEnd > 1 && groupIndex == 0;

  /// Ob überhaupt zwischen Gruppen unterschieden wird. Schießen alle zusammen,
  /// gibt es keine Gruppenanzeige — es gäbe nichts zu unterscheiden.
  bool get hasGroups => lineup.groupLabels.length > 1;

  bool get isInWarningPeriod =>
      phase == TimerPhase.active && remainingTime <= warningThreshold;

  SignalState get signal => SignalState(
    phase: phase,
    isWarning: isInWarningPeriod,
    isPaused: isPaused,
  );

  bool get canStart => phase == TimerPhase.idle;
  bool get canPause => isRunning && !isPaused;
  bool get canResume => isPaused;
  bool get isFinished => phase == TimerPhase.ended;

  CompetitionState copyWith({
    Duration? remainingTime,
    TimerPhase? phase,
    int? currentEnd,
    int? totalEnds,
    int? groupIndex,
    CompetitionLineup? lineup,
    CompetitionDiscipline? discipline,
    Duration? preparationTime,
    Duration? shootingTime,
    Duration? warningThreshold,
    bool? isRunning,
    bool? isPaused,
  }) {
    return CompetitionState(
      remainingTime: remainingTime ?? this.remainingTime,
      phase: phase ?? this.phase,
      currentEnd: currentEnd ?? this.currentEnd,
      totalEnds: totalEnds ?? this.totalEnds,
      groupIndex: groupIndex ?? this.groupIndex,
      lineup: lineup ?? this.lineup,
      discipline: discipline ?? this.discipline,
      preparationTime: preparationTime ?? this.preparationTime,
      shootingTime: shootingTime ?? this.shootingTime,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
