import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('Glass renders its child', (WidgetTester tester) async {
    const key = Key('glass-child');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Glass(child: Container(key: key)),
        ),
      ),
    );

    expect(find.byType(Glass), findsOneWidget);
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('InteractiveGlass renders child and ignores hover', (
    WidgetTester tester,
  ) async {
    const childKey = Key('interactive-glass-child');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              pressedScale: 1.28,
              child: SizedBox(key: childKey, width: 24, height: 24),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveGlass), findsOneWidget);
    expect(find.byKey(childKey), findsOneWidget);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(InteractiveGlass)));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

    await gesture.removePointer();
  });

  testWidgets('InteractiveGlass scales while pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              pressedScale: 1.28,
              child: const Icon(Icons.grid_view),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.28,
    );

    await gesture.up();
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('InteractiveGlass stays scaled while pressed and dragged', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              pressedScale: 1.28,
              child: const Icon(Icons.grid_view),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.28,
    );

    await gesture.up();
  });

  testWidgets('InteractiveGlass reports taps', (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveGlass(
            onTap: () => tapped = true,
            child: const Icon(Icons.grid_view),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InteractiveGlass));
    expect(tapped, isTrue);
  });

  testWidgets('CLIconButton uses InteractiveGlass and reports taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLIconButton(icon: Icons.add, onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.byType(InteractiveGlass), findsOneWidget);

    await tester.tap(find.byType(CLIconButton));
    expect(tapped, isTrue);
  });
}
