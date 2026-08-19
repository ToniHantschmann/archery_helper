import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../providers/competition_ui_providers.dart';

/// Die Maße der LED-Wand am Außenstand.
///
/// 96 × 64 cm bei 5 mm Pixelabstand sind **192 × 128 Pixel** — das ist kein
/// Layout, das man responsiv rechnet, sondern ein Raster, das man abzählt.
/// Alle Werte sind deshalb ganzzahlig: ein halber Pixel ist hier ein Viertel
/// Zentimeter Wand.
///
/// Die Aufteilung folgt daraus, dass die Uhr *breiten*- und nicht
/// höhenbegrenzt ist. Eine proportional gesetzte Ziffer kann nur so hoch
/// werden, wie die Breite es zulässt — die restliche Höhe bliebe leer. Die Uhr
/// bekommt deshalb die volle Höhe und wird vertikal gestreckt
/// ([timeScaleY]), also hoch und schmal wie auf jeder Anzeigetafel. Gruppe und
/// Ampelfläche stehen dafür seitlich übereinander statt als Zeile darüber.
class LedPanelSpec {
  const LedPanelSpec._();

  static const double width = 192;
  static const double height = 128;

  /// Die linke Spalte: oben die Ampelfläche, darunter das Gruppenkürzel.
  static const double sideWidth = 38;
  static const double signalHeight = 76;
  static const double groupHeight = height - signalHeight;

  /// Schwarzer Abstand zwischen Spalte und Uhr.
  static const double gutter = 6;

  /// Rechter Rand der Uhr. Sie steht rechtsbündig, damit beim Stellenwechsel
  /// (etwa 100 → 99) die verbleibenden Ziffern ihre Spalte behalten.
  static const double timeInset = 6;

  /// Was der Uhr an Breite bleibt.
  static const double timeWidth = width - sideWidth - gutter - timeInset;

  /// Damit das Gruppenkürzel nicht an beiden Kanten der Spalte klebt.
  static const double groupInset = 3;

  static const double groupWidth = sideWidth - 2 * groupInset;

  /// Die breitesten Strings, für die die Uhr Platz haben muss.
  ///
  /// `4:00` ist die Freiluft-Schusszeit und damit das längste, was das aktuelle
  /// Format zeigen kann. `240` steht für die reine Sekundenzahl, zwischen der
  /// hier später wahlweise umgeschaltet werden soll — sie steht schon jetzt in
  /// der Liste, damit die Schriftgröße nicht eines Tages nur noch für eines von
  /// beiden Formaten reicht.
  static const timeSamples = ['4:00', '240'];

  /// Alle Gruppenkürzel, die es gibt (siehe `CompetitionLineup`).
  static const groupSamples = ['AB', 'CD'];

  /// Beide Stile erben **nicht** vom umgebenden `DefaultTextStyle`.
  ///
  /// Das Panel muss überall gleich aussehen: im eigenen Schirm, in der Vorschau
  /// und als Ecke über der Bedienansicht — dort hängt es außerhalb jedes
  /// `Material`, und `MaterialApp` schiebt in dem Fall seinen Fallback-Stil
  /// unter, mitsamt gelber Unterstreichung und `monospace`. Eine andere Schrift
  /// als die, an der [timeFontSize] ausgemessen wurde, würde die Uhr aber
  /// abschneiden statt sie überlaufen zu lassen — und das sieht man nur auf der
  /// Wand. `inherit: false` macht Messung und Anzeige zur selben Sache.
  static const _timeBase = TextStyle(
    inherit: false,
    color: AppPalette.ledWhite,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0,
    // Gleiche Vorschubbreite für jede Ziffer. Erst das macht die
    // Rechtsbündigkeit zu einer festen Spalte, statt sich darauf zu verlassen,
    // dass die Schrift ihre Ziffern zufällig gleich breit setzt.
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const _groupBase = TextStyle(
    inherit: false,
    color: AppPalette.ledWhite,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0,
  );

  static double? _timeFontSize;
  static double? _groupFontSize;

  /// Die größte Schrift, in der [timeSamples] noch in [timeWidth] passt.
  ///
  /// Gemessen statt festgeschrieben: wie breit eine Ziffer ist, ist eine
  /// Eigenschaft der Schrift und keine, die man einer Zahl im Quelltext ansieht
  /// — schon der Testlauf rechnet mit einer anderen als die App. Bemessen wird
  /// immer am *breitesten denkbaren* String, nie am gerade angezeigten: die
  /// Ziffern dürfen zwischen „0:09" und „0:10" nicht ihre Größe wechseln.
  static double get timeFontSize =>
      _timeFontSize ??= _fit(timeSamples, _timeBase, timeWidth, height);

  /// Die vertikale Streckung: die Zeile füllt danach genau [height].
  ///
  /// Ohne sie bliebe die halbe Wand leer, denn eine proportional gesetzte
  /// Ziffer kann nur so hoch werden, wie die Breite es erlaubt. Hoch und schmal
  /// ist bei Anzeigetafeln ohnehin der Normalfall.
  static double get timeScaleY => height / timeFontSize;

  /// Versalhöhe im Verhältnis zur Schriftgröße (Roboto: `sCapHeight` 1456 von
  /// 2048 Einheiten).
  ///
  /// Steht als Zahl hier, weil Flutter die Tintenkante eines Textes nicht
  /// herausgibt und die Schrift das Einzige ist, was die optische Mitte der
  /// Ziffern bestimmt. Nur [timeNudgeY] hängt davon ab — ein falscher Wert
  /// verschiebt die Uhr also um ein paar Pixel, er kann nichts abschneiden.
  static const double _capHeightRatio = 0.711;

  /// Wie weit die Uhr nach unten gerückt wird.
  ///
  /// Eine Zeilenbox ist nicht um ihre Tinte herum gebaut: unten reserviert sie
  /// Platz für Unterlängen, die Ziffern nicht haben, oben den Unterschied
  /// zwischen Oberlänge und Versalhöhe. Beides ist bei einer Uhr leer, und
  /// beides ist verschieden groß — ohne Ausgleich säße die Zahl um rund acht
  /// Pixel zu hoch in der Wand, also gut vier Zentimeter.
  static double get timeNudgeY {
    final baseline = _baselineOf(timeSamples.first, timeStyle);
    final emptyBelow = timeFontSize - baseline;
    final emptyAbove = baseline - _capHeightRatio * timeFontSize;

    return (emptyBelow - emptyAbove) / 2 * timeScaleY;
  }

  static double get groupFontSize =>
      _groupFontSize ??= _fit(groupSamples, _groupBase, groupWidth, groupHeight);

  static TextStyle get timeStyle => _timeBase.copyWith(fontSize: timeFontSize);

  static TextStyle get groupStyle =>
      _groupBase.copyWith(fontSize: groupFontSize);

  static double _fit(
    List<String> samples,
    TextStyle base,
    double maxWidth,
    double maxHeight,
  ) {
    const probe = 100.0;

    final widest = samples
        .map((sample) => _measure(sample, base.copyWith(fontSize: probe)))
        .reduce(math.max);

    return math.min(probe * maxWidth / widest, maxHeight);
  }

  static double _measure(String text, TextStyle style) =>
      _painterFor(text, style).width;

  static double _baselineOf(String text, TextStyle style) =>
      _painterFor(
        text,
        style,
      ).computeDistanceToActualBaseline(TextBaseline.alphabetic);

  static TextPainter _painterFor(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Schlüssel für die Layout-Tests — die Zellen dürfen nicht überlaufen, und ein
/// zu großer Font *clippt*, was kein `RenderFlex`-Overflow ist und deshalb von
/// der allgemeinen Overflow-Prüfung nicht gefunden würde.
const ledTimeKey = ValueKey('led-time');
const ledGroupKey = ValueKey('led-group');

/// Der Wettkampfstand auf 192 × 128 Pixeln: Restzeit, Gruppe, Ampelfarbe.
///
/// Mehr passt nicht, und mehr braucht es auf der Schießlinie auch nicht. Der
/// Hintergrund ist echtes Schwarz statt [AppPalette.base] — auf einer Wand mit
/// 5000 Nits ist eine dunkelgraue Fläche keine Zurückhaltung, sondern eine
/// leuchtende Fläche. Schwarz heißt hier: Diode aus.
class LedPanel extends ConsumerWidget {
  const LedPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ColoredBox(
      color: AppPalette.ledBlack,
      child: SizedBox(
        width: LedPanelSpec.width,
        height: LedPanelSpec.height,
        child: Row(
          children: [
            _LedSideColumn(),
            SizedBox(width: LedPanelSpec.gutter),
            Expanded(child: _LedTime()),
          ],
        ),
      ),
    );
  }
}

/// Ampelfläche und Gruppenkürzel.
class _LedSideColumn extends ConsumerWidget {
  const _LedSideColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalColor = ref.watch(competitionLedSignalColorProvider);
    final group = ref.watch(competitionLedGroupProvider);

    // Schießen alle zusammen, gibt es keine Gruppe anzuzeigen — dann bekommt
    // die Farbfläche die ganze Höhe, statt eine leere Zelle freizuhalten.
    if (group == null) {
      return SizedBox(
        width: LedPanelSpec.sideWidth,
        height: LedPanelSpec.height,
        child: ColoredBox(color: signalColor),
      );
    }

    return SizedBox(
      width: LedPanelSpec.sideWidth,
      height: LedPanelSpec.height,
      child: Column(
        children: [
          SizedBox(
            height: LedPanelSpec.signalHeight,
            width: double.infinity,
            child: ColoredBox(color: signalColor),
          ),
          SizedBox(
            height: LedPanelSpec.groupHeight,
            width: double.infinity,
            child: Center(
              child: Text(
                group,
                key: ledGroupKey,
                style: LedPanelSpec.groupStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Restzeit über die volle Höhe der Wand.
class _LedTime extends ConsumerWidget {
  const _LedTime();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(competitionLedTimeProvider);
    final color = ref.watch(competitionLedTimeColorProvider);

    return Padding(
      padding: const EdgeInsets.only(right: LedPanelSpec.timeInset),
      child: Align(
        alignment: Alignment.centerRight,
        child: Transform.translate(
          offset: Offset(0, LedPanelSpec.timeNudgeY),
          child: Transform.scale(
            scaleY: LedPanelSpec.timeScaleY,
            // Feste Schriftgröße, keine `FittedBox`: der Platz ist hier ein
            // Pixelraster, und eine mit dem Inhalt wandernde Größe würde die
            // Ziffern zwischen „0:09" und „0:10" verschieden hoch machen.
            child: Text(
              time,
              key: ledTimeKey,
              style: LedPanelSpec.timeStyle.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
