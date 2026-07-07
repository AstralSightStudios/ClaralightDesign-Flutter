import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

RadialGradient? _highlightGradient(WidgetTester tester) {
  final decoratedBoxes = tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  );

  for (final decoratedBox in decoratedBoxes) {
    final decoration = decoratedBox.decoration;
    if (decoration is BoxDecoration && decoration.gradient is RadialGradient) {
      return decoration.gradient! as RadialGradient;
    }
  }

  return null;
}

Offset _transformAroundCenter(Matrix4 matrix, Size size, Offset position) {
  final center = Offset(size.width / 2, size.height / 2);
  final effectiveTransform = Matrix4.identity()
    ..translateByDouble(center.dx, center.dy, 0, 1)
    ..multiply(matrix)
    ..translateByDouble(-center.dx, -center.dy, 0, 1);

  return MatrixUtils.transformPoint(effectiveTransform, position);
}

Offset _highlightVisualPosition(WidgetTester tester, Size surfaceSize) {
  const scaleKey = Key('interactive-glass-scale-transform');
  const deformationKey = Key('interactive-glass-deformation-transform');
  final highlightCenter = _highlightGradient(tester)!.center as Alignment;
  final highlightPosition = Offset(
    ((highlightCenter.x + 1) / 2) * surfaceSize.width,
    ((highlightCenter.y + 1) / 2) * surfaceSize.height,
  );
  final deformedPosition = _transformAroundCenter(
    tester.widget<Transform>(find.byKey(deformationKey)).transform,
    surfaceSize,
    highlightPosition,
  );

  return _transformAroundCenter(
    tester.widget<Transform>(find.byKey(scaleKey)).transform,
    surfaceSize,
    deformedPosition,
  );
}

void main() {
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

  testWidgets('InteractiveGlass shows highlight only while pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              width: 80,
              height: 60,
              child: Icon(Icons.grid_view),
            ),
          ),
        ),
      ),
    );

    expect(_highlightGradient(tester), isNull);

    final pressLocation = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(
      pressLocation,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(_highlightGradient(tester), isNotNull);

    await gesture.up();
    await tester.pump();

    expect(_highlightGradient(tester), isNull);
  });

  testWidgets('InteractiveGlass places highlight under the mouse pointer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              width: 80,
              height: 60,
              child: Icon(Icons.grid_view),
            ),
          ),
        ),
      ),
    );

    final surfaceRect = tester.getRect(find.byType(InteractiveGlass));
    final pressLocation = surfaceRect.topLeft + const Offset(60, 10);
    final gesture = await tester.startGesture(
      pressLocation,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(
      _highlightVisualPosition(tester, const Size(80, 60)).dx,
      moreOrLessEquals(60, epsilon: 0.001),
    );
    expect(
      _highlightVisualPosition(tester, const Size(80, 60)).dy,
      moreOrLessEquals(10, epsilon: 0.001),
    );

    await gesture.moveTo(surfaceRect.topLeft + const Offset(20, 45));
    await tester.pump();

    expect(
      _highlightVisualPosition(tester, const Size(80, 60)).dx,
      moreOrLessEquals(20, epsilon: 0.001),
    );
    expect(
      _highlightVisualPosition(tester, const Size(80, 60)).dy,
      moreOrLessEquals(45, epsilon: 0.001),
    );

    await gesture.up();
  });

  testWidgets(
    'InteractiveGlass keeps highlight visually under pointer when scaled',
    (WidgetTester tester) async {
      const surfaceSize = Size(80, 60);
      const pointerLocalPosition = Offset(60, 10);
      const pressedScale = 1.35;
      final surfaceCenter = Offset(
        surfaceSize.width / 2,
        surfaceSize.height / 2,
      );
      final compensatedLocalPosition =
          surfaceCenter + (pointerLocalPosition - surfaceCenter) / pressedScale;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveGlass(
                width: surfaceSize.width,
                height: surfaceSize.height,
                pressedScale: pressedScale,
                child: Icon(Icons.grid_view),
              ),
            ),
          ),
        ),
      );

      final surfaceRect = tester.getRect(find.byType(InteractiveGlass));
      final gesture = await tester.startGesture(
        surfaceRect.topLeft + pointerLocalPosition,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final highlightCenter = _highlightGradient(tester)!.center as Alignment;

      expect(
        highlightCenter.x,
        moreOrLessEquals(
          (compensatedLocalPosition.dx / surfaceSize.width) * 2 - 1,
          epsilon: 0.0001,
        ),
      );
      expect(
        highlightCenter.y,
        moreOrLessEquals(
          (compensatedLocalPosition.dy / surfaceSize.height) * 2 - 1,
          epsilon: 0.0001,
        ),
      );

      await gesture.up();
    },
  );

  test('InteractiveGlass defaults to LiquidButton blur and press scale', () {
    const glass = InteractiveGlass(child: SizedBox());

    expect(glass.blur, 2);
    expect(glass.pressedScale, moreOrLessEquals(1 + 4 / 48));
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

  testWidgets('InteractiveGlass keeps the same Glass border while pressed', (
    WidgetTester tester,
  ) async {
    const border = Border.fromBorderSide(
      BorderSide(color: Color(0x33445566), width: 1.5),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveGlass(
              border: border,
              child: Icon(Icons.grid_view),
            ),
          ),
        ),
      ),
    );

    BoxBorder currentBorder() =>
        tester.widget<Glass>(find.byType(Glass)).border!;

    expect(currentBorder(), border);

    final center = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(currentBorder(), border);

    await gesture.up();
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
}
