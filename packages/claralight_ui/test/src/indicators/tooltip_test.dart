import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLTooltip shows its message on long press', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              message: '这按钮是干嘛的',
              child: CLIconButton(icon: Icons.help, onPressed: () {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('这按钮是干嘛的'), findsNothing);

    await tester.longPress(find.byType(CLIconButton));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('这按钮是干嘛的'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('CLTooltip can disable its long-press trigger', (
    WidgetTester tester,
  ) async {
    const anchorKey = Key('hover-only-anchor');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              message: 'Hover only',
              enableLongPress: false,
              child: SizedBox(
                key: anchorKey,
                width: 40,
                height: 40,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(anchorKey));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Hover only'), findsNothing);
  });

  testWidgets('CLTooltip does not re-enter mouse tracking while animating', (
    WidgetTester tester,
  ) async {
    const anchorKey = Key('hover-anchor');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              delay: Duration.zero,
              message: 'Hover tooltip',
              child: SizedBox(
                key: anchorKey,
                width: 40,
                height: 40,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final anchor = tester.getRect(find.byKey(anchorKey));

    for (var i = 0; i < 20; i++) {
      await mouse.moveTo(anchor.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await mouse.moveTo(Offset(anchor.center.dx, anchor.top - 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('CLTooltip supports physical positions without an arrow', (
    WidgetTester tester,
  ) async {
    const anchorKey = Key('tooltip-anchor');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              message: 'Right tooltip',
              position: CLPopoverPosition.right,
              showArrow: false,
              child: SizedBox(
                key: anchorKey,
                width: 40,
                height: 40,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(anchorKey));
    await tester.pump(const Duration(milliseconds: 250));

    final anchor = tester.getRect(find.byKey(anchorKey));
    final message = tester.getRect(find.text('Right tooltip'));
    expect(message.left, greaterThan(anchor.right));
  });
}
