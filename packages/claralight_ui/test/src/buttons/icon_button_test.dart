import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets(
    'CLIconButton uses LiquidButton surface metrics and reports taps',
    (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CLIconButton(icon: Icons.add, onPressed: () => tapped = true),
          ),
        ),
      );

      expect(find.byType(InteractiveGlass), findsOneWidget);
      final glass = tester.widget<InteractiveGlass>(
        find.byType(InteractiveGlass),
      );
      expect(glass.size, 48);
      expect(glass.blur, 2);
      expect(glass.pressedScale, moreOrLessEquals(1 + 4 / 48));
      expect(glass.backgroundColor, Colors.transparent);

      await tester.tap(find.byType(CLIconButton));
      expect(tapped, isTrue);
    },
  );

  testWidgets('CLIconButton applies tint and surface color', (
    WidgetTester tester,
  ) async {
    const tint = Color(0xFF00FF00);
    const surfaceColor = Color(0x669900FF);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLIconButton(
            icon: Icons.add,
            tint: tint,
            surfaceColor: surfaceColor,
            onPressed: () {},
          ),
        ),
      ),
    );

    final glass = tester.widget<InteractiveGlass>(
      find.byType(InteractiveGlass),
    );
    expect(glass.backgroundColor, surfaceColor);
  });

  testWidgets('CLIconButton applies tint with LiquidButton surface alpha', (
    WidgetTester tester,
  ) async {
    const tint = Color(0xFF00FF00);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLIconButton(icon: Icons.add, tint: tint, onPressed: () {}),
        ),
      ),
    );

    final glass = tester.widget<InteractiveGlass>(
      find.byType(InteractiveGlass),
    );
    expect(glass.backgroundColor, tint.withValues(alpha: 0.75));
  });

  testWidgets('CLIconButton can use non-interactive material indication', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLIconButton(
            icon: Icons.add,
            isInteractive: false,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveGlass), findsNothing);
    expect(find.byType(Glass), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);

    final overlayStacks = tester
        .widgetList<Stack>(find.byType(Stack))
        .where((stack) => stack.children.firstOrNull is Glass);
    expect(overlayStacks, isNotEmpty);
    expect(overlayStacks.single.clipBehavior, Clip.none);
    expect(overlayStacks.single.children.last, isA<Positioned>());

    await tester.tap(find.byType(CLIconButton));
    expect(tapped, isTrue);
  });
}
