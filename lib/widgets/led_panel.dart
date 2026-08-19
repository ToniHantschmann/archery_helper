import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../models/settings.dart';
import '../providers/competition_ui_providers.dart';
import '../providers/settings_provider.dart';

/// Die Maße der LED-Wand am Außenstand.
///
/// 96 × 64 cm bei 5 mm Pixelabstand sind **192 × 128 Pixel** — das ist kein
/// Layout, das man responsiv rechnet, sondern ein Raster, das man abzählt.
/// Alle Werte sind deshalb ganzzahlig: ein halber Pixel ist hier ein Viertel
/// Zentimeter Wand.
///
/// Die Aufteilung folgt daraus, dass die Uhr *breiten*- und nicht
/// höhenbegrenzt ist. Eine proportional gesetzte Ziffernfolge kann nur so hoch
/// werden, wie die Breite es zulässt — „4:00" ist knapp zwei Ziffernhöhen
/// breit. Die Uhr bekommt deshalb die volle *Breite* der Wand; ihre natürliche
/// Höhe füllt damit fast die ganze Zelle, und die [timeScaleY] übrig bleibende
/// Streckung ist mit rund einem Zehntel so klein, dass man sie nicht sieht.
/// Stünde sie stattdessen neben einer Seitenspalte, bliebe ihr nur gut die
/// halbe Breite — und die fehlende Höhe müsste sie sich mit einer Streckung auf
/// das Doppelte holen, was die Ziffern sichtbar verzerrt.
///
/// Ampel, Gruppe und Passe stehen dafür als Zeile darunter statt seitlich
/// übereinander. Das kostet die Uhr die 28 Pixel dieser Zeile und gibt den
/// beiden Beschriftungen dafür deutlich mehr Breite, als eine Spalte ihnen
/// lassen könnte — und sie sind *breiten*begrenzt, ihre Zellenhöhe reizen sie
/// ohnehin nicht aus.
class LedPanelSpec {
  const LedPanelSpec._();

  static const double width = 192;
  static const double height = 128;

  /// Was die Uhr an Höhe bekommt.
  static const double timeHeight = 100;

  /// Schwarzer Abstand zwischen Uhr und Zeile. Ohne ihn stößt die Ampelfläche
  /// direkt an die Ziffern.
  static const double rowGutter = 2;

  /// Was der Zeile bleibt — so summieren sich die drei Bänder immer auf
  /// [height], ganz gleich, wie an den beiden darüber gedreht wird.
  static const double rowHeight = height - timeHeight - rowGutter;

  /// Die drei Zellen der Zeile: Gruppenkürzel, Ampelfläche, Passenzähler.
  ///
  /// Ein Drittel der Wand für jedes — beide Beschriftungen sind zwei Zeichen
  /// breit („AB", „30") und stehen in derselben [labelFontSize], also gibt es
  /// keinen Grund, ihnen verschieden viel Platz zu geben. Das Drittel ist auch
  /// die Bedingung an den Passenzähler und nicht bloß seine Folge: mit der
  /// Gesamtzahl („30/30") bräuchte er die anderthalbfache Breite, und die
  /// müssten die anderen beiden bezahlen.
  static const double cellWidth = width / 3;

  /// Seitlicher Rand der Uhr. Sie steht rechtsbündig, damit beim Stellenwechsel
  /// (etwa 100 → 99) die verbleibenden Ziffern ihre Spalte behalten.
  ///
  /// Rechtsbündig heißt hier: innerhalb des *Blocks* ihres Formats. Der Block
  /// selbst steht mittig — siehe [timeShiftX].
  static const double timeInset = 6;

  /// Was der Uhr an Breite bleibt.
  static const double timeWidth = width - 2 * timeInset;

  /// Damit die Beschriftungen nicht an den Kanten ihrer Zelle kleben.
  static const double labelInset = 3;

  /// Die Breite, in die Gruppenkürzel *und* Passenzähler passen müssen — beide
  /// stehen in einer gleich breiten Zelle, also ist es dieselbe Zahl und nicht
  /// zwei.
  static const double labelWidth = cellWidth - 2 * labelInset;

  /// Der breiteste String, den jedes Zeitformat zeigen kann.
  ///
  /// `4:00` ist die Freiluft-Schusszeit und damit das Längste, was `m:ss`
  /// hergibt; `240` dieselbe Zeit als reine Sekundenzahl. Nach Format getrennt,
  /// weil daran zwei verschiedene Fragen hängen: beide zusammen ergeben die
  /// Schriftgröße ([timeSamples]), jeder für sich die Mitte seines Formats
  /// ([timeShiftX]).
  static const timeSamplesByFormat = {
    TimeFormat.minutesSeconds: '4:00',
    TimeFormat.seconds: '240',
  };

  /// Die breitesten Strings, für die die Uhr Platz haben muss — beide Formate
  /// zusammen, damit die Schriftgröße nicht für eines von beiden zu knapp wird.
  static final List<String> timeSamples = List.unmodifiable(
    timeSamplesByFormat.values,
  );

  /// Alle Gruppenkürzel, die es gibt (siehe `CompetitionLineup`).
  static const groupSamples = ['AB', 'CD'];

  /// Der breiteste Passenzähler, den es geben kann.
  ///
  /// Aus [Settings.maxCompetitionEnds] gebaut statt hingeschrieben: eine
  /// heraufgesetzte Obergrenze in den Einstellungen darf die Schrift nicht
  /// stillschweigend zu groß stehen lassen — bei dreistelligen Passen wäre die
  /// Zelle zu schmal.
  static final endSamples = ['${Settings.maxCompetitionEnds}'];

  /// Alle drei Stile erben **nicht** vom umgebenden `DefaultTextStyle`.
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

  /// Derselbe Stil wie die Gruppe — die beiden stehen nebeneinander in einer
  /// Zeile und sind gleich wichtig, also gibt es zwischen ihnen auch keine
  /// Rangordnung zu setzen. Weiß und nicht [AppPalette.ledDim]: das Grau heißt
  /// auf diesem Panel „die Uhr ist pausiert" und darf keine zweite Bedeutung
  /// bekommen.
  static const _endBase = TextStyle(
    inherit: false,
    color: AppPalette.ledWhite,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static double? _timeFontSize;
  static double? _labelFontSize;

  /// Die größte Schrift, in der [timeSamples] noch in [timeWidth] passt.
  ///
  /// Gemessen statt festgeschrieben: wie breit eine Ziffer ist, ist eine
  /// Eigenschaft der Schrift und keine, die man einer Zahl im Quelltext ansieht
  /// — schon der Testlauf rechnet mit einer anderen als die App. Bemessen wird
  /// immer am *breitesten denkbaren* String, nie am gerade angezeigten: die
  /// Ziffern dürfen zwischen „0:09" und „0:10" nicht ihre Größe wechseln.
  static double get timeFontSize =>
      _timeFontSize ??= _fit(timeSamples, _timeBase, timeWidth, timeHeight);

  /// Wie weit die Uhr aus der Rechtsbündigkeit nach links rückt.
  ///
  /// Rechtsbündig allein hieße: an der rechten Kante des Bandes. Das steht nur
  /// für das Format mittig, an dem die Schriftgröße bemessen wurde — die reine
  /// Sekundenzahl ist um einen Doppelpunkt schmaler und säße damit sichtbar
  /// nach rechts gerückt. Verschoben wird deshalb nicht die einzelne Zahl,
  /// sondern der ganze *Block* des Formats: zentriert wird der breitestmögliche
  /// String, den dieses Format zeigen kann, und innerhalb dieses Blocks bleibt
  /// alles rechtsbündig. Beim Stellenwechsel (etwa 100 → 99) behalten die
  /// Ziffern also weiterhin ihre Spalte, es wird links nur Luft frei.
  ///
  /// Der Sprung zwischen den beiden Blöcken ist im Betrieb nie zu sehen: das
  /// Zeitformat wird vor der Runde eingestellt, nicht während einer Passe.
  static double timeShiftX(TimeFormat format) =>
      -(timeWidth - _formatWidth(format)) / 2;

  static final _formatWidths = <TimeFormat, double>{};

  static double _formatWidth(TimeFormat format) => _formatWidths[format] ??=
      _measure(timeSamplesByFormat[format]!, timeStyle);

  /// Die vertikale Streckung: die Zeile füllt danach genau [timeHeight].
  ///
  /// Über die volle Breite gesetzt ist die Uhr von sich aus schon fast so hoch
  /// wie ihre Zelle — die Streckung ist deshalb keine Gestaltung mehr, sondern
  /// nur noch das letzte Zehntel, das die Rundung übrig lässt. Sie wird nicht
  /// eingestellt, sie fällt aus dem Raster.
  static double get timeScaleY => timeHeight / timeFontSize;

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

  /// Die Schriftgröße **beider** Beschriftungen der Infozeile.
  ///
  /// Eine Größe und nicht zwei: nebeneinander in derselben Zeile liest sich ein
  /// Größenunterschied nicht als Rangfolge, sondern als Versehen. Genommen wird
  /// die kleinere der beiden Passungen — die größere passte ja gerade nicht
  /// mehr in ihre Zelle. Beide Strings sind zwei Zeichen breit und landen im
  /// Drittel der Wand deshalb bei der vollen [rowHeight]; geht das eines Tages
  /// nicht mehr auf, werden eben beide zusammen kleiner statt eines von beiden.
  ///
  /// Ohne Streckung, anders als die Uhr: [timeScaleY] ist deren Eigenheit, weil
  /// sie als Einzige ihre Zelle sonst nicht ausfüllen würde. Auf die Zeilenhöhe
  /// gestreckt wäre der Passenzähler unleserlich schmal.
  static double get labelFontSize => _labelFontSize ??= math.min(
    _fit(groupSamples, _groupBase, labelWidth, rowHeight),
    _fit(endSamples, _endBase, labelWidth, rowHeight),
  );

  static TextStyle get timeStyle => _timeBase.copyWith(fontSize: timeFontSize);

  static TextStyle get groupStyle =>
      _groupBase.copyWith(fontSize: labelFontSize);

  static TextStyle get endStyle => _endBase.copyWith(fontSize: labelFontSize);

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

  static double _baselineOf(String text, TextStyle style) => _painterFor(
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
const ledEndKey = ValueKey('led-end');

/// Der Wettkampfstand auf 192 × 128 Pixeln: Restzeit, Gruppe, Passe,
/// Ampelfarbe.
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
        child: Column(
          children: [
            SizedBox(
              height: LedPanelSpec.timeHeight,
              width: double.infinity,
              child: _LedTime(),
            ),
            SizedBox(height: LedPanelSpec.rowGutter),
            SizedBox(height: LedPanelSpec.rowHeight, child: _LedInfoRow()),
          ],
        ),
      ),
    );
  }
}

/// Ampelfläche, Gruppenkürzel und Passenzähler.
class _LedInfoRow extends ConsumerWidget {
  const _LedInfoRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalColor = ref.watch(competitionLedSignalColorProvider);
    final group = ref.watch(competitionLedGroupProvider);

    // Schießen alle zusammen, gibt es keine Gruppe anzuzeigen — dann fällt ihre
    // Zelle an die Farbfläche, statt leer freigehalten zu werden. Sie reicht
    // dann bis an den linken Rand; der Passenzähler steht in beiden Fällen an
    // derselben Stelle.
    final signalWidth = group == null
        ? 2 * LedPanelSpec.cellWidth
        : LedPanelSpec.cellWidth;

    return SizedBox(
      width: LedPanelSpec.width,
      height: LedPanelSpec.rowHeight,
      child: Row(
        children: [
          if (group != null)
            SizedBox(
              width: LedPanelSpec.cellWidth,
              height: double.infinity,
              child: Center(
                child: Text(
                  group,
                  key: ledGroupKey,
                  style: LedPanelSpec.groupStyle,
                ),
              ),
            ),
          SizedBox(
            width: signalWidth,
            height: double.infinity,
            child: ColoredBox(color: signalColor),
          ),
          const SizedBox(
            width: LedPanelSpec.cellWidth,
            height: double.infinity,
            child: Center(child: _LedEnd()),
          ),
        ],
      ),
    );
  }
}

/// Die wievielte Passe gerade läuft — „3".
class _LedEnd extends ConsumerWidget {
  const _LedEnd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      ref.watch(competitionLedEndProvider),
      key: ledEndKey,
      style: LedPanelSpec.endStyle,
    );
  }
}

/// Die Restzeit über die volle Breite der Wand.
class _LedTime extends ConsumerWidget {
  const _LedTime();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(competitionLedTimeProvider);
    final color = ref.watch(competitionLedTimeColorProvider);
    // Dieselbe Quelle, aus der auch der String sein Format bekommt — die
    // Verschiebung und die Zahl dürfen nicht aus zwei Einstellungen kommen.
    final format = ref.watch(timeFormatProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LedPanelSpec.timeInset),
      child: Align(
        alignment: Alignment.centerRight,
        child: Transform.translate(
          // Nur gezeichnet, nicht gelayoutet: die Uhr bleibt rechtsbündig, der
          // Block rückt in die Mitte.
          offset: Offset(
            LedPanelSpec.timeShiftX(format),
            LedPanelSpec.timeNudgeY,
          ),
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
