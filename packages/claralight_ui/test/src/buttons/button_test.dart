import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLButton is built on InteractiveGlass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLButton(label: '继续', onPressed: () {}),
        ),
      ),
    );

    expect(find.byType(InteractiveGlass), findsOneWidget);
    final glass = tester.widget<InteractiveGlass>(
      find.byType(InteractiveGlass),
    );
    expect(glass.width, CLButton.defaultWidth);
    expect(glass.height, CLButton.defaultHeight);
  });

  testWidgets('CLButton keeps fixed height and fixed icon edge insets', (
    WidgetTester tester,
  ) async {
    const leftKey = Key('left-icon');
    const rightKey = Key('right-icon');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLButton(
              width: 260,
              label: '继续',
              leadingIcon: SizedBox(key: leftKey, width: 24, height: 24),
              trailingIcon: SizedBox(key: rightKey, width: 24, height: 24),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(Glass));
    final leftRect = tester.getRect(find.byKey(leftKey));
    final rightRect = tester.getRect(find.byKey(rightKey));
    final textRect = tester.getRect(find.text('继续'));

    expect(buttonRect.height, 50);
    expect(leftRect.left - buttonRect.left, 16);
    expect(buttonRect.right - rightRect.right, 16);
    expect(textRect.center.dx, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton keeps label visually centered with one-sided icon', (
    WidgetTester tester,
  ) async {
    const leftKey = Key('left-icon');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLButton(
              width: 220,
              label: '继续',
              leadingIcon: SizedBox(key: leftKey, width: 24, height: 24),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(Glass));
    final leftRect = tester.getRect(find.byKey(leftKey));
    final textRect = tester.getRect(find.text('继续'));

    expect(leftRect.left - buttonRect.left, 16);
    expect(textRect.center.dx, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton keeps label centered with trailing-only icon', (
    WidgetTester tester,
  ) async {
    const rightKey = Key('right-icon');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLButton(
              width: 220,
              label: '继续',
              trailingIcon: SizedBox(key: rightKey, width: 24, height: 24),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(Glass));
    final rightRect = tester.getRect(find.byKey(rightKey));
    final textRect = tester.getRect(find.text('继续'));

    expect(buttonRect.right - rightRect.right, 16);
    expect(textRect.center.dx, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton keeps label centered without icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLButton(width: 220, label: '继续', onPressed: () {}),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(Glass));
    final textRect = tester.getRect(find.text('继续'));

    expect(textRect.center.dx, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton reports taps', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLButton(label: '继续', onPressed: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.byType(CLButton));

    expect(tapped, isTrue);
  });
}
