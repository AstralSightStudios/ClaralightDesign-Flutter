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
    const scaleKey = Key('interactive-glass-scale-transform');
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

    double scale() {
      return tester
          .widget<Transform>(find.byKey(scaleKey))
          .transform
          .storage[0];
    }

    expect(find.byType(InteractiveGlass), findsOneWidget);
    expect(find.byKey(childKey), findsOneWidget);
    expect(scale(), 1);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(InteractiveGlass)));
    await tester.pump();

    expect(scale(), 1);

    await gesture.removePointer();
  });

  testWidgets('InteractiveGlass defaults to 44px with centered child', (
    WidgetTester tester,
  ) async {
    const surfaceKey = Key('interactive-glass-surface');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: InteractiveGlass(child: Icon(Icons.grid_view))),
        ),
      ),
    );

    final surface = tester.widget<SizedBox>(find.byKey(surfaceKey));
    final padding = tester.widget<Padding>(find.byType(Padding).last);

    expect(surface.width, 44);
    expect(surface.height, 44);
    expect(padding.padding, EdgeInsets.zero);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.grid_view),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });

  testWidgets('InteractiveGlass supports rectangular surfaces', (
    WidgetTester tester,
  ) async {
    const surfaceKey = Key('interactive-glass-surface');
    const radius = BorderRadius.all(Radius.circular(14));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              width: 120,
              height: 48,
              borderRadius: radius,
              child: Text('Rectangle'),
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<SizedBox>(find.byKey(surfaceKey));

    expect(surface.width, 120);
    expect(surface.height, 48);
    expect(tester.widget<Glass>(find.byType(Glass)).borderRadius, radius);
  });

  testWidgets('InteractiveGlass scales while pressed and springs back', (
    WidgetTester tester,
  ) async {
    const scaleKey = Key('interactive-glass-scale-transform');
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

    double scale() {
      return tester
          .widget<Transform>(find.byKey(scaleKey))
          .transform
          .storage[0];
    }

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(scale(), moreOrLessEquals(1.28, epsilon: 0.001));

    await gesture.up();
    await tester.pump();

    var undershot = false;
    for (var i = 0; i < 18; i += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      undershot = undershot || scale() < 0.999;
    }

    expect(undershot, isTrue);

    await tester.pumpAndSettle();

    expect(scale(), moreOrLessEquals(1, epsilon: 0.001));
  });

  testWidgets('InteractiveGlass stays scaled while pressed and dragged', (
    WidgetTester tester,
  ) async {
    const scaleKey = Key('interactive-glass-scale-transform');
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

    double scale() {
      return tester
          .widget<Transform>(find.byKey(scaleKey))
          .transform
          .storage[0];
    }

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();

    expect(scale(), moreOrLessEquals(1.28, epsilon: 0.001));

    await gesture.up();
  });

  testWidgets('InteractiveGlass deforms while pressed and dragged', (
    WidgetTester tester,
  ) async {
    const deformationKey = Key('interactive-glass-deformation-transform');
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

    Matrix4 deformationMatrix() {
      return tester.widget<Transform>(find.byKey(deformationKey)).transform;
    }

    expect(deformationMatrix().storage[0], 1);
    expect(deformationMatrix().storage[5], 1);

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(36, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(deformationMatrix().storage[0], greaterThan(1));
    expect(deformationMatrix().storage[0], lessThan(1.09));
    expect(deformationMatrix().storage[5], lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(deformationMatrix().storage[0], moreOrLessEquals(1, epsilon: 0.001));
    expect(deformationMatrix().storage[5], moreOrLessEquals(1, epsilon: 0.001));
  });

  test('InteractiveGlass defaults to a bouncy release spring', () {
    const glass = InteractiveGlass(child: SizedBox());

    expect(glass.spring.stiffness, 520);
    expect(glass.spring.damping, 16);
  });

  test('InteractiveGlass validates positive finite sizing inputs', () {
    expect(
      () => InteractiveGlass(size: 0, child: const SizedBox()),
      throwsAssertionError,
    );
    expect(
      () => InteractiveGlass(width: -1, child: const SizedBox()),
      throwsAssertionError,
    );
    expect(
      () => InteractiveGlass(height: double.infinity, child: const SizedBox()),
      throwsAssertionError,
    );
    expect(
      () => InteractiveGlass(dragTension: 0, child: const SizedBox()),
      throwsAssertionError,
    );
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
    expect(
      tester.widget<InteractiveGlass>(find.byType(InteractiveGlass)).size,
      44,
    );

    await tester.tap(find.byType(CLIconButton));
    expect(tapped, isTrue);
  });
}
