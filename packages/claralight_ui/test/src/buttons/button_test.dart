import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLButton uses LiquidButton surface metrics', (
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
    expect(glass.height, 48);
    expect(glass.blur, 2);
    expect(glass.pressedScale, moreOrLessEquals(1 + 4 / 48));
    expect(glass.backgroundColor.a, moreOrLessEquals(0.75));
  });

  testWidgets('CLButton centers icon and label group with 8px gaps', (
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
    final groupCenter = (leftRect.left + rightRect.right) / 2;

    expect(buttonRect.height, 48);
    expect(textRect.left - leftRect.right, 8);
    expect(rightRect.left - textRect.right, 8);
    expect(groupCenter, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton centers leading icon and label as one group', (
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
    final groupCenter = (leftRect.left + textRect.right) / 2;

    expect(textRect.left - leftRect.right, 8);
    expect(groupCenter, moreOrLessEquals(buttonRect.center.dx));
  });

  testWidgets('CLButton centers label and trailing icon as one group', (
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
    final groupCenter = (textRect.left + rightRect.right) / 2;

    expect(rightRect.left - textRect.right, 8);
    expect(groupCenter, moreOrLessEquals(buttonRect.center.dx));
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

  testWidgets('CLButton disabled skips interactive press feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CLButton(label: '继续')),
      ),
    );

    expect(find.byType(InteractiveGlass), findsNothing);
    expect(find.byType(Glass), findsOneWidget);
  });

  testWidgets('CLButton can use non-interactive material indication', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLButton(
            label: '继续',
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

    await tester.tap(find.byType(CLButton));

    expect(tapped, isTrue);
  });

  testWidgets('CLButton applies tint with LiquidButton surface alpha', (
    WidgetTester tester,
  ) async {
    const tint = Color(0xFF00FF00);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLButton(label: '继续', tint: tint, onPressed: () {}),
        ),
      ),
    );

    final glass = tester.widget<InteractiveGlass>(
      find.byType(InteractiveGlass),
    );

    expect(glass.backgroundColor, tint.withValues(alpha: 0.75));
  });

  testWidgets('CLButton lets tint and surface color override variant', (
    WidgetTester tester,
  ) async {
    const tint = Color(0xFF00FF00);
    const surfaceColor = Color(0x669900FF);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLButton(
            label: '继续',
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
}
