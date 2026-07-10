import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLToggle', () {
    testWidgets('renders flat track and thumb with default metrics', (
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
      final shape =
          (track.decoration! as ShapeDecoration).shape
              as RoundedSuperellipseBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(CLToggle.trackHeight / 2),
      );
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
      // Any horizontal movement marks the gesture as a drag, so this
      // settles below the midpoint instead of toggling like a tap.
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
      final offColor = (offTrack.decoration! as ShapeDecoration).color!;

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
      final onColor = (onTrack.decoration! as ShapeDecoration).color!;

      expect(offColor, isNot(equals(onColor)));
    });

    testWidgets('flat thumb press scale stays subtle', (
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
      expect(transform.transform.storage[0], closeTo(1.12, 0.001));

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
