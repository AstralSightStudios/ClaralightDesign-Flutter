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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CLIconButton)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('这按钮是干嘛的'), findsOneWidget);
    await gesture.up();
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

  testWidgets('CLTooltip hides before its first reveal frame', (
    WidgetTester tester,
  ) async {
    const anchorKey = Key('same-frame-anchor');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              delay: Duration.zero,
              message: 'Same-frame tooltip',
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

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final anchor = tester.getRect(find.byKey(anchorKey));

    await mouse.moveTo(anchor.center);
    await tester.pump();
    await mouse.moveTo(Offset(anchor.center.dx, anchor.top - 2));
    await tester.pumpAndSettle();

    expect(find.text('Same-frame tooltip'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
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

    await tester.pump(const Duration(milliseconds: 610));

    expect(tester.takeException(), isNull);
    expect(find.text('Hover tooltip'), findsNothing);
  });

  testWidgets('CLTooltip shares and extends a warm hover window', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tooltipPair());
    final mouse = await _mouseAtOrigin(tester);
    final first = tester.getRect(find.byKey(_firstAnchorKey));
    final second = tester.getRect(find.byKey(_secondAnchorKey));

    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text(_firstMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_firstMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(second.center);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_secondMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_firstMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 610));
    expect(find.text(_firstMessage), findsNothing);
    expect(find.text(_secondMessage), findsNothing);
  });

  testWidgets('CLTooltip grace expires at exactly 500 milliseconds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tooltipPair());
    final mouse = await _mouseAtOrigin(tester);
    final first = tester.getRect(find.byKey(_firstAnchorKey));
    final second = tester.getRect(find.byKey(_secondAnchorKey));

    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text(_firstMessage), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 500));

    await mouse.moveTo(second.center);
    await tester.pump();
    expect(find.text(_secondMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text(_secondMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_secondMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 610));
  });

  testWidgets('CLTooltip canceled dwell does not warm siblings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tooltipPair());
    final mouse = await _mouseAtOrigin(tester);
    final first = tester.getRect(find.byKey(_firstAnchorKey));
    final second = tester.getRect(find.byKey(_secondAnchorKey));

    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 200));
    await mouse.moveTo(Offset.zero);
    await tester.pump();

    await mouse.moveTo(second.center);
    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text(_secondMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_secondMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 610));
  });

  testWidgets('CLTooltip grace bypasses a custom cold delay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tooltipPair(
        firstDelay: const Duration(milliseconds: 700),
        secondDelay: const Duration(milliseconds: 700),
      ),
    );
    final mouse = await _mouseAtOrigin(tester);
    final first = tester.getRect(find.byKey(_firstAnchorKey));
    final second = tester.getRect(find.byKey(_secondAnchorKey));

    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 699));
    expect(find.text(_firstMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_firstMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(second.center);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(_secondMessage), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 610));
  });

  for (final incidentalMouseExit in [false, true]) {
    testWidgets(
      'CLTooltip long press stays cold with mouse exit: $incidentalMouseExit',
      (WidgetTester tester) async {
        await tester.pumpWidget(_tooltipPair());
        final mouse = await _mouseAtOrigin(tester);
        final first = tester.getRect(find.byKey(_firstAnchorKey));
        final second = tester.getRect(find.byKey(_secondAnchorKey));

        await mouse.moveTo(first.center);
        await tester.pump();
        final touch = await tester.startGesture(first.center);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text(_firstMessage), findsOneWidget);

        if (incidentalMouseExit) {
          await mouse.moveTo(Offset.zero);
          await tester.pump();
        }
        await touch.up();
        await tester.pumpAndSettle();

        await mouse.moveTo(second.center);
        await tester.pump(const Duration(milliseconds: 449));
        expect(find.text(_secondMessage), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.text(_secondMessage), findsOneWidget);

        await mouse.moveTo(Offset.zero);
        await tester.pump(const Duration(milliseconds: 610));
      },
    );
  }

  testWidgets('CLTooltip rapid sibling traversal leaves no stale overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tooltipPair());
    final mouse = await _mouseAtOrigin(tester);
    final first = tester.getRect(find.byKey(_firstAnchorKey));
    final second = tester.getRect(find.byKey(_secondAnchorKey));

    await mouse.moveTo(first.center);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text(_firstMessage), findsOneWidget);

    for (var index = 0; index < 20; index += 1) {
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(index.isEven ? second.center : first.center);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
    }

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 610));

    expect(tester.takeException(), isNull);
    expect(find.text(_firstMessage), findsNothing);
    expect(find.text(_secondMessage), findsNothing);
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(anchorKey)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    final anchor = tester.getRect(find.byKey(anchorKey));
    final message = tester.getRect(find.text('Right tooltip'));
    expect(message.left, greaterThan(anchor.right));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

const _firstAnchorKey = Key('grace-first-anchor');
const _secondAnchorKey = Key('grace-second-anchor');
const _firstMessage = 'First tooltip';
const _secondMessage = 'Second tooltip';

Widget _tooltipPair({
  Duration firstDelay = const Duration(milliseconds: 450),
  Duration secondDelay = const Duration(milliseconds: 450),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CLTooltip(
              delay: firstDelay,
              message: _firstMessage,
              child: const SizedBox(
                key: _firstAnchorKey,
                width: 40,
                height: 40,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
            const SizedBox(width: 8),
            CLTooltip(
              delay: secondDelay,
              message: _secondMessage,
              child: const SizedBox(
                key: _secondAnchorKey,
                width: 40,
                height: 40,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<TestGesture> _mouseAtOrigin(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}
