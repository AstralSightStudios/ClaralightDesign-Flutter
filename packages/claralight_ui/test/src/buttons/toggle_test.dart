import 'package:claralight_ui/src/buttons/toggle.dart';
import 'package:claralight_ui/src/surfaces/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLToggle', () {
    testWidgets('renders track and thumb with default metrics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: false, onChanged: (_) {})),
          ),
        ),
      );

      final toggleBox = find
          .descendant(
            of: find.byType(CLToggle),
            matching: find.byType(SizedBox),
          )
          .first;
      final sizedBox = tester.widget<SizedBox>(toggleBox);
      expect(sizedBox.width, CLToggle.trackWidth);
      expect(sizedBox.height, CLToggle.trackHeight);

      final track = tester.widget<Container>(
        find.byKey(const Key('cl-toggle-track')),
      );
      expect(
        (track.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(CLToggle.trackHeight / 2),
      );

      final glass = tester.widget<Glass>(
        find.descendant(
          of: find.byType(CLToggle),
          matching: find.byType(Glass),
        ),
      );
      expect(
        glass.borderRadius,
        BorderRadius.circular(CLToggle.thumbHeight / 2),
      );
      expect(glass.refractiveIndex, 1);

      final surfacePaint = tester.widget<CustomPaint>(
        find.byKey(const Key('cl-toggle-thumb-surface')),
      );
      expect((surfacePaint.painter! as dynamic).surfaceAlpha, 1);
    });

    testWidgets('thumb starts at left padding when value is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: false, onChanged: (_) {})),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.byKey(const Key('cl-toggle-thumb')),
      );
      expect(positioned.left, CLToggle.thumbPadding);
    });

    testWidgets('thumb starts at right padding when value is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: true, onChanged: (_) {})),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.byKey(const Key('cl-toggle-thumb')),
      );
      expect(positioned.left, CLToggle.thumbPadding + CLToggle.dragWidth);
    });

    testWidgets('toggles value on tap', (WidgetTester tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CLToggle(value: value, onChanged: (v) => value = v),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CLToggle));
      await tester.pumpAndSettle();

      expect(value, isTrue);
    });

    testWidgets('drags thumb past midpoint toggles on', (
      WidgetTester tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CLToggle(value: value, onChanged: (v) => value = v),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(CLToggle.dragWidth + 4, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(value, isTrue);
    });

    testWidgets('any horizontal movement is treated as a drag', (
      WidgetTester tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CLToggle(value: value, onChanged: (v) => value = v),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      // Android LiquidToggle marks didDrag as soon as dragAmount.x != 0f,
      // so this settles below the midpoint instead of toggling like a tap.
      await gesture.moveBy(const Offset(4, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(value, isFalse);
    });

    testWidgets('drag past midpoint but below end toggles on and snaps on', (
      WidgetTester tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: CLToggle(
                    value: value,
                    onChanged: (v) => setState(() => value = v),
                  ),
                );
              },
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(CLToggle.dragWidth - 4, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find.byKey(const Key('cl-toggle-thumb')),
      );
      expect(value, isTrue);
      expect(
        positioned.left,
        closeTo(CLToggle.thumbPadding + CLToggle.dragWidth, 0.01),
      );
    });

    testWidgets('mirrors drag in RTL', (WidgetTester tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: CLToggle(value: value, onChanged: (v) => value = v),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      // In RTL, dragging left (negative dx) moves the thumb toward the "on"
      // position.
      await gesture.moveBy(const Offset(-(CLToggle.dragWidth + 4), 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(value, isTrue);
    });

    testWidgets('reverts visual state when parent rejects a tap', (
      WidgetTester tester,
    ) async {
      var requestedValue = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CLToggle(
                value: false,
                onChanged: (v) => requestedValue = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CLToggle));
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find.byKey(const Key('cl-toggle-thumb')),
      );
      expect(requestedValue, isTrue);
      expect(positioned.left, closeTo(CLToggle.thumbPadding, 0.01));
    });

    testWidgets('reverts dragged fraction on pointer cancel', (
      WidgetTester tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CLToggle(value: value, onChanged: (v) => value = v),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(CLToggle.dragWidth, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      final positioned = tester.widget<Positioned>(
        find.byKey(const Key('cl-toggle-thumb')),
      );
      expect(value, isFalse);
      expect(positioned.left, closeTo(CLToggle.thumbPadding, 0.01));
    });

    testWidgets('track color changes with value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(child: CLToggle(value: false, onChanged: (_) {})),
          ),
        ),
      );

      final offTrack = tester.widget<Container>(
        find.byKey(const Key('cl-toggle-track')),
      );
      final offColor = (offTrack.decoration! as BoxDecoration).color!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(child: CLToggle(value: true, onChanged: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final onTrack = tester.widget<Container>(
        find.byKey(const Key('cl-toggle-track')),
      );
      final onColor = (onTrack.decoration! as BoxDecoration).color!;

      expect(offColor, isNot(equals(onColor)));
    });

    testWidgets('thumb uses Android press scale and lens values', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: false, onChanged: (_) {})),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(CLToggle));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byKey(const Key('cl-toggle-thumb')),
          matching: find.byType(Transform),
        ),
      );
      final matrix = transform.transform.storage;
      expect(matrix[0], closeTo(1.5, 0.001));
      expect(matrix[5], closeTo(1.5, 0.001));

      final glass = tester.widget<Glass>(
        find.descendant(
          of: find.byType(CLToggle),
          matching: find.byType(Glass),
        ),
      );
      expect(glass.blur, closeTo(0, 0.001));
      expect(glass.backgroundColor.a, closeTo(0, 0.001));
      final surfacePaint = tester.widget<CustomPaint>(
        find.byKey(const Key('cl-toggle-thumb-surface')),
      );
      expect(
        (surfacePaint.painter! as dynamic).surfaceAlpha,
        closeTo(0, 0.001),
      );
      expect(glass.thickness, closeTo(10, 0.001));
      expect(glass.refractiveIndex, closeTo(1.2, 0.001));
      expect(glass.chromaticAberration, closeTo(0.01, 0.001));
      expect(glass.useRoundedSuperellipse, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('does not respond when disabled', (WidgetTester tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: value, onChanged: null)),
          ),
        ),
      );

      await tester.tap(find.byType(CLToggle));
      await tester.pumpAndSettle();

      expect(value, isFalse);

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(CLToggle),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.enabled, isFalse);
    });

    testWidgets('semantics reports toggle role and value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CLToggle(value: true, onChanged: (_) {})),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(CLToggle),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.toggled, isTrue);
      expect(semantics.properties.enabled, isTrue);
      expect(semantics.properties.onTap, isNotNull);
    });
  });
}
