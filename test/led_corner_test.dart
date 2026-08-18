import 'package:archery_helper/widgets/led_corner.dart';
import 'package:archery_helper/widgets/led_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Mediaplayer schneidet ein festes Rechteck aus dem HDMI-Bild. Trifft die
/// Ecke es nicht auf den Pixel genau, zeigt die Wand einen verschobenen
/// Ausschnitt — und das merkt man erst am Turniertag. Dieser Test ist deshalb
/// der eigentliche Grund, warum der Modus so gebaut ist, wie er gebaut ist.
void main() {
  Future<void> pumpCorner(WidgetTester tester, {required double ratio}) async {
    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = Size(1920 * ratio, 1080 * ratio);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Stack(
            alignment: Alignment.topLeft,
            // Steht für die Bedienansicht: füllt das Bild und liegt darunter.
            children: [SizedBox.expand(child: ColoredBox(color: Colors.teal)), LedCorner()],
          ),
        ),
      ),
    );
  }

  for (final ratio in [1.0, 2.0, 3.0]) {
    testWidgets('at devicePixelRatio $ratio the panel covers exactly the crop', (
      tester,
    ) async {
      await pumpCorner(tester, ratio: ratio);

      final panel = find.byType(LedPanel);

      // In Gerätepixeln gerechnet, denn das ist die Einheit, in der die Wand
      // denkt: logische Pixel sind nur bei einem Verhältnis von 1 dasselbe.
      expect(tester.getTopLeft(panel) * ratio, Offset.zero);
      expect(
        tester.getBottomRight(panel) * ratio,
        const Offset(LedPanelSpec.width, LedPanelSpec.height),
      );
    });
  }

  testWidgets('the panel is drawn on top of everything below it', (
    tester,
  ) async {
    await pumpCorner(tester, ratio: 1);

    final stack = tester.widget<Stack>(
      find.ancestor(of: find.byType(LedCorner), matching: find.byType(Stack)).first,
    );

    expect(stack.children.last, isA<LedCorner>());
  });

  testWidgets('the reserved size is what the panel really takes up', (
    tester,
  ) async {
    await pumpCorner(tester, ratio: 2);

    final context = tester.element(find.byType(LedCorner));
    final panel = find.byType(LedPanel);

    expect(
      ledCornerSize(context),
      Size(
        tester.getBottomRight(panel).dx - tester.getTopLeft(panel).dx,
        tester.getBottomRight(panel).dy - tester.getTopLeft(panel).dy,
      ),
    );
  });

  testWidgets('the clock and the group label are there', (tester) async {
    await pumpCorner(tester, ratio: 1);

    expect(find.byKey(ledTimeKey), findsOneWidget);
    expect(find.byKey(ledGroupKey), findsOneWidget);
  });
}
