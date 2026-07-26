import 'dart:ui' show SemanticsAction, SemanticsValidationResult;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui/src/overlays/anchored_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(
    Widget child, {
    Alignment alignment = Alignment.center,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Align(
              alignment: alignment,
              child: SizedBox(width: 240, child: child),
            ),
          ),
        ),
      ),
    );
  }

  final stepUp = find.byKey(const Key('cl-text-field-step-up'));
  final stepDown = find.byKey(const Key('cl-text-field-step-down'));
  final dragZone = find.byKey(const Key('cl-text-field-stepper-drag-zone'));
  final prefixZone = find.byKey(const Key('cl-text-field-prefix-scrub-zone'));
  final scrubRuler = find.byKey(const Key('cl-text-field-scrub-ruler'));
  final scrubOverlay = find.byKey(
    const Key('cl-text-field-scrub-value-overlay'),
  );

  BorderSide fieldBorder(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(CLTextField),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as ShapeDecoration;
    return (decoration.shape as RoundedSuperellipseBorder).side;
  }

  testWidgets('sizes use the standard control heights', (tester) async {
    for (final size in CLControlSize.values) {
      await tester.pumpWidget(host(CLTextField(size: size)));

      expect(
        tester.getSize(find.byType(CLTextField)).height,
        size.controlHeight,
        reason: 'height of $size',
      );
    }
  });

  testWidgets('step buttons only appear for numeric fields with a step', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const CLTextField(keyboardType: TextInputType.number, step: 1)),
    );
    expect(stepUp, findsOneWidget);
    expect(stepDown, findsOneWidget);

    await tester.pumpWidget(
      host(const CLTextField(keyboardType: TextInputType.number)),
    );
    expect(stepUp, findsNothing);
    expect(stepDown, findsNothing);

    await tester.pumpWidget(
      host(const CLTextField(keyboardType: TextInputType.text, step: 1)),
    );
    expect(stepUp, findsNothing);
    expect(stepDown, findsNothing);
  });

  testWidgets('numeric stepper preserves the original inline geometry', (
    tester,
  ) async {
    final controller = TextEditingController(text: '78');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('W'),
          suffix: const Text('px'),
          step: 1,
          size: CLControlSize.small,
        ),
      ),
    );

    final prefixRect = tester.getRect(find.text('W'));
    final fieldRect = tester.getRect(find.byType(CupertinoTextField));
    final suffixRect = tester.getRect(find.text('px'));
    final stepperRect = tester.getRect(stepUp);

    expect(fieldRect.left - prefixRect.right, closeTo(10, 0.01));
    expect(suffixRect.left - fieldRect.right, closeTo(0, 0.01));
    expect(stepperRect.left - suffixRect.right, greaterThan(10));

    final typography = CLThemeData().typography;
    expect(
      DefaultTextStyle.of(tester.element(find.text('W'))).style.fontFamily,
      typography.callout.fontFamily,
    );
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .style
          ?.fontFamily,
      typography.monoStrong.fontFamily,
    );
    expect(
      DefaultTextStyle.of(tester.element(find.text('px'))).style.fontFamily,
      typography.mono.fontFamily,
    );
  });

  testWidgets('the whole numeric stepper surface focuses the text field', (
    tester,
  ) async {
    final controller = TextEditingController(text: '78');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          prefix: const Text('W'),
          suffix: const Text('px'),
          step: 1,
          size: CLControlSize.small,
        ),
      ),
    );

    final controlRect = tester.getRect(find.byType(CLTextField));
    await tester.tapAt(controlRect.center);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('buttons step, format, and report the edited text', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0.2');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final changes = <String>[];

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          step: 0.1,
          format: (value) => value.toStringAsFixed(2),
          onChanged: changes.add,
        ),
      ),
    );

    await tester.tap(stepUp);
    await tester.pump();

    expect(controller.text, '0.30');
    expect(changes, ['0.30']);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('step buttons clamp values and can repair out-of-range input', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 2,
          min: 1,
          max: 10,
        ),
      ),
    );

    await tester.tap(stepUp);
    await tester.pump();
    expect(controller.text, '12');

    await tester.tap(stepDown);
    await tester.pump();
    expect(controller.text, '10');

    controller.text = '2';
    await tester.pump();
    await tester.tap(stepDown);
    await tester.pump();
    expect(controller.text, '1');
  });

  testWidgets('unmodified arrow keys step a focused numeric field', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 2,
        ),
      ),
    );

    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, '6');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.text, '6');

    controller.value = const TextEditingValue(
      text: '6',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.text, '6');
  });

  testWidgets('numeric scrub zones preserve geometry and use an EW cursor', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
          size: CLControlSize.small,
        ),
      ),
    );

    final controlRect = tester.getRect(find.byType(CLTextField));
    final trailingRect = tester.getRect(dragZone);
    final prefixRect = tester.getRect(prefixZone);
    final upRect = tester.getRect(stepUp);

    expect(trailingRect.width, 24);
    expect(trailingRect.left, upRect.left);
    expect(trailingRect.right, closeTo(controlRect.right, 1.01));
    expect(prefixRect.left, closeTo(controlRect.left, 1.01));
    expect(prefixRect.width, greaterThan(tester.getSize(find.text('X')).width));
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where(
            (region) => region.cursor == SystemMouseCursors.resizeLeftRight,
          ),
      hasLength(2),
    );

    controller.text = 'invalid';
    await tester.pump();
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where(
            (region) => region.cursor == SystemMouseCursors.resizeLeftRight,
          ),
      isEmpty,
    );

    controller.text = '4';
    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );
    expect(prefixZone, findsNothing);
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where(
            (region) => region.cursor == SystemMouseCursors.resizeLeftRight,
          ),
      hasLength(1),
    );
  });

  testWidgets('mouse scrub only starts in prefix and arrow regions', (
    tester,
  ) async {
    final controller = TextEditingController(text: '10');
    final focusNode = FocusNode();
    final changes = <String>[];
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          suffix: const Text('px'),
          step: 2,
          onChanged: changes.add,
        ),
      ),
    );

    final controlRect = tester.getRect(find.byType(CLTextField));
    final outside = await tester.startGesture(
      controlRect.center,
      kind: PointerDeviceKind.mouse,
    );
    await outside.moveBy(const Offset(24, 0));
    await outside.up();
    await tester.pump();
    expect(controller.text, '10');
    expect(scrubRuler, findsNothing);

    final scrub = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.mouse,
    );
    await scrub.moveBy(const Offset(4, 0));
    await tester.pump();
    await tester.pump();
    expect(controller.text, '10');
    expect(scrubRuler, findsOneWidget);
    expect(scrubOverlay, findsOneWidget);
    expect(find.byType(CLAnimatedNumber), findsOneWidget);
    expect(
      find.descendant(of: scrubOverlay, matching: find.text('px')),
      findsOneWidget,
    );

    await scrub.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '12');

    await scrub.moveBy(const Offset(17, 0));
    await tester.pump();
    expect(controller.text, '16');
    expect(changes, ['12', '16']);
    expect(focusNode.hasFocus, isTrue);

    await scrub.up();
    await tester.pumpAndSettle();
    expect(scrubOverlay, findsNothing);
  });

  testWidgets('prefix scrub moves right to increase and left to decrease', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(controller.text, '5');
    expect(scrubRuler, findsOneWidget);

    await mouse.moveBy(const Offset(-16, 0));
    await tester.pump();
    expect(controller.text, '3');

    await mouse.up();
  });

  testWidgets('vertical bands select strict 2/4/8/16/32px spacing', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -4));
    await tester.pump();

    await mouse.moveBy(const Offset(0, -16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '1');

    await mouse.moveBy(const Offset(0, -40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(2, 0));
    await tester.pump();
    expect(controller.text, '2');

    await mouse.moveBy(const Offset(0, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(16, 0));
    await tester.pump();
    expect(controller.text, '3');

    await mouse.moveBy(const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(32, 0));
    await tester.pump();
    expect(controller.text, '4');
    expect(
      find.byKey(const Key('cl-text-field-scrub-multiplier')),
      findsNothing,
    );

    await mouse.up();
  });

  testWidgets('ruler spacing and step threshold interpolate together', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -4));
    await mouse.moveBy(const Offset(0, -16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '0');
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(controller.text, '1');

    await mouse.up();
  });

  testWidgets('40px vertical bands use 4px return hysteresis', (tester) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -4));
    await mouse.moveBy(const Offset(0, -16));
    await mouse.moveBy(const Offset(0, 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '1');

    await mouse.moveBy(const Offset(0, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '1');
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '2');

    await mouse.up();
  });

  testWidgets('one pointer update commits and haptics atomically', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    final changes = <String>[];
    final stepped = <String>[];
    final platformCalls = <MethodCall>[];
    addTearDown(controller.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
          onChanged: changes.add,
          onStepped: stepped.add,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();
    await mouse.moveBy(const Offset(24, 0));
    await tester.pump();

    expect(controller.text, '3');
    expect(changes, ['3']);
    expect(stepped, ['3']);
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      hasLength(1),
    );

    await mouse.up();
    await tester.pumpAndSettle();
    await tester.tap(stepUp);
    await tester.pump();
    expect(controller.text, '4');
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      hasLength(2),
    );
  });

  testWidgets('scrub discards bound overshoot for immediate reversal', (
    tester,
  ) async {
    final controller = TextEditingController(text: '9');
    final changes = <String>[];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          step: 1,
          max: 10,
          onChanged: changes.add,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, 4));
    await mouse.moveBy(const Offset(24, 0));
    await tester.pump();
    expect(controller.text, '10');

    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(controller.text, '10');

    await mouse.moveBy(const Offset(-8, 0));
    await tester.pump();
    expect(controller.text, '9');
    expect(changes, ['10', '9']);

    await mouse.up();
  });

  testWidgets('stylus activates at 4px and still steps every 8px at 1x', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    final stylus = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.stylus,
    );
    await stylus.moveBy(const Offset(3, 0));
    await tester.pump();
    expect(scrubRuler, findsNothing);
    expect(controller.text, '4');

    await stylus.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(scrubRuler, findsOneWidget);
    expect(controller.text, '4');

    await stylus.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '5');
    await stylus.up();
  });

  testWidgets('pointer cancel stops a pending arrow repeat', (tester) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(stepUp),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 499));
    await mouse.cancel();
    await tester.pump(const Duration(milliseconds: 160));

    expect(controller.text, '0');
    expect(scrubOverlay, findsNothing);
  });

  testWidgets('trackpad pan zoom does not scrub numeric values', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    await tester.drag(
      dragZone,
      const Offset(40, 0),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pump();

    expect(controller.text, '4');
    expect(scrubRuler, findsNothing);
  });

  testWidgets('mouse hold repeats then hands off cleanly to 2D scrub', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(stepUp),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 499));
    expect(controller.text, '0');
    expect(scrubRuler, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.text, '1');
    expect(focusNode.hasFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.text, '2');

    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(controller.text, '3');
    expect(scrubRuler, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.text, '3');
    await mouse.up();
  });

  testWidgets('touch long press waits for 8px movement before scrubbing', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    final focusNode = FocusNode();
    final platformCalls = <MethodCall>[];
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    final touch = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(focusNode.hasFocus, isFalse);
    expect(fieldBorder(tester).color.a, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(focusNode.hasFocus, isFalse);
    expect(fieldBorder(tester).color, CLThemeData().colors.accent);
    expect(controller.text, '1');
    expect(scrubRuler, findsNothing);
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isEmpty,
    );

    await touch.moveBy(const Offset(7, 0));
    await tester.pump();
    expect(controller.text, '1');
    expect(scrubRuler, findsNothing);

    await touch.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(controller.text, '2');
    expect(scrubRuler, findsOneWidget);
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      hasLength(1),
    );

    await touch.up();
  });

  testWidgets('touch hold repeats without visual then hands off to scrub', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );

    final touch = await tester.startGesture(
      tester.getCenter(stepUp),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusNode.hasFocus, isFalse);
    expect(scrubRuler, findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.text, '1');
    expect(scrubRuler, findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.text, '2');

    await touch.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(controller.text, '3');
    expect(scrubRuler, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.text, '3');

    await touch.up();
  });

  testWidgets(
    'scrub direction stays right-to-increase for every arrow layout',
    (tester) async {
      final controller = TextEditingController(text: '4');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        host(
          CLTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            step: 1,
            stepperDirection: CLNumericStepperDirection.down,
          ),
        ),
      );

      final mouse = await tester.startGesture(
        tester.getCenter(dragZone),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(8, 0));
      await tester.pump();
      expect(controller.text, '5');
      await mouse.up();
    },
  );

  testWidgets(
    'value overlay flips around the field and keeps compact geometry',
    (tester) async {
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);

      Widget field() => CLTextField(
        controller: controller,
        keyboardType: TextInputType.number,
        prefix: const Text('X'),
        suffix: const Text('px'),
        step: 1,
      );

      await tester.pumpWidget(host(field(), alignment: Alignment.topCenter));
      var mouse = await tester.startGesture(
        tester.getCenter(prefixZone),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(4, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      var fieldRect = tester.getRect(find.byType(CLTextField));
      var overlayRect = tester.getRect(scrubOverlay);
      expect(overlayRect.top, greaterThanOrEqualTo(fieldRect.bottom + 7));
      expect(overlayRect.width, greaterThanOrEqualTo(80));
      await mouse.up();
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(field(), alignment: Alignment.bottomCenter));
      mouse = await tester.startGesture(
        tester.getCenter(prefixZone),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(4, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      fieldRect = tester.getRect(find.byType(CLTextField));
      overlayRect = tester.getRect(scrubOverlay);
      expect(overlayRect.bottom, lessThanOrEqualTo(fieldRect.top - 7));
      await mouse.up();
    },
  );

  testWidgets('value popover tracks a scrub field inside a scroller', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12');
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: 1200,
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: SizedBox(
                  width: 240,
                  child: CLTextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    prefix: const Text('W'),
                    suffix: const Text('px'),
                    step: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    scrollController.jumpTo(400);
    await tester.pump();

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    await tester.pump();

    final fieldRect = tester.getRect(find.byType(CLTextField));
    final prefixRect = tester.getRect(prefixZone);
    final overlayRect = tester.getRect(scrubOverlay);
    final rulerCenter = (prefixRect.right + fieldRect.right) / 2;
    expect(overlayRect.bottom, lessThan(fieldRect.top));
    expect(fieldRect.top - overlayRect.bottom, lessThan(80));
    expect(overlayRect.center.dx, closeTo(rulerCenter, 1));

    await mouse.up();
  });

  testWidgets('overlay uses the numeric formatter and safely moves suffix', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    final suffixKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          prefix: const Text('X'),
          suffix: Text('kg', key: suffixKey),
          step: 0.25,
          format: (value) => value.toStringAsFixed(2),
        ),
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(prefixZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    await tester.pump();

    final number = tester.widget<CLAnimatedNumber>(
      find.byType(CLAnimatedNumber),
    );
    expect(number.formatter!(1), '1.00');
    expect(find.byKey(suffixKey), findsOneWidget);
    expect(
      find.descendant(of: scrubOverlay, matching: find.byKey(suffixKey)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(suffixKey),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );

    await mouse.up();
  });

  testWidgets('reduced motion removes scaling and snaps ruler spacing', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
        disableAnimations: true,
      ),
    );

    final mouse = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, 4));
    await tester.pump();
    var popover = tester.widget<CLAnchoredOverlay>(
      find.byKey(const Key('cl-text-field-scrub-popover')),
    );
    expect(popover.opacity, 0);
    expect(popover.scale, 1);

    await tester.pump(const Duration(milliseconds: 62));
    popover = tester.widget<CLAnchoredOverlay>(
      find.byKey(const Key('cl-text-field-scrub-popover')),
    );
    expect(popover.opacity, inExclusiveRange(0, 1));
    expect(popover.scale, 1);

    await mouse.moveBy(const Offset(0, -24));
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(controller.text, '2');

    await mouse.up();
  });

  testWidgets('value overlay reuses the complete arrow popover material', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );
    final mouse = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(4, 0));
    await tester.pump();
    await tester.pump();

    final theme = CLThemeData();
    final popover = tester.widget<CLAnchoredOverlay>(
      find.byKey(const Key('cl-text-field-scrub-popover')),
    );
    expect(popover.position, CLPopoverPosition.top);
    expect(popover.showArrow, isTrue);
    expect(popover.padding, const EdgeInsets.fromLTRB(16, 10, 16, 8));
    expect(popover.borderRadius, theme.radii.panel);
    expect(popover.outlineColor, theme.colors.outlineStrong);
    expect(popover.shadowBlur, 24);
    expect(popover.shadowOffset, const Offset(0, 10));
    expect(scrubOverlay, findsOneWidget);
    await mouse.up();
  });

  testWidgets('macOS pointer steps use the native alignment haptic channel', (
    tester,
  ) async {
    const channel = MethodChannel('dev.claralight.ui/haptics');
    final calls = <MethodCall>[];
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          step: 1,
        ),
      ),
    );
    final mouse = await tester.startGesture(
      tester.getCenter(dragZone),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, 4));
    await mouse.moveBy(const Offset(8, 0));
    await tester.pump();

    expect(controller.text, '2');
    expect(calls, contains(isMethodCall('selectionClick', arguments: null)));
    debugDefaultTargetPlatformOverride = null;
    await mouse.up();
  });

  testWidgets('wheel steps once, preserves focus, and filters signals', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 2,
          min: 0,
          max: 10,
        ),
      ),
    );

    final position = tester.getCenter(find.byType(CLTextField));
    bool? allowedPlatformDefault;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, -120),
        onRespond: ({required allowPlatformDefault}) {
          allowedPlatformDefault = allowPlatformDefault;
        },
      ),
    );
    await tester.pump();
    expect(controller.text, '6');
    expect(focusNode.hasFocus, isFalse);
    expect(allowedPlatformDefault, isFalse);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(30, -10),
      ),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        position: position,
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.pump();
    expect(controller.text, '6');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.text, '6');

    controller.text = '10';
    await tester.pump();
    var respondedAtBoundary = false;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, -20),
        onRespond: ({required allowPlatformDefault}) {
          respondedAtBoundary = true;
        },
      ),
    );
    await tester.pump();
    expect(controller.text, '10');
    expect(respondedAtBoundary, isTrue);
  });

  testWidgets('wheel yields to an ancestor scroller at a numeric bound', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            height: 1000,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: CLTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  step: 1,
                  min: 0,
                  max: 10,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final position = tester.getCenter(find.byType(CLTextField));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, 20),
      ),
    );
    await tester.pump();
    expect(controller.text, '3');
    expect(scrollController.offset, 0);

    controller.text = '0';
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, 20),
      ),
    );
    await tester.pump();
    expect(controller.text, '0');
    expect(scrollController.offset, 20);
  });

  testWidgets('numeric semantics expose available step directions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '1');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          step: 1,
          min: 0,
          max: 2,
        ),
      ),
    );

    var node = tester.getSemantics(find.byType(CLTextField));
    var data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.value, '1');
    expect(data.increasedValue, '2');
    expect(data.decreasedValue, '0');

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(controller.text, '2');
    expect(focusNode.hasFocus, isFalse);

    node = tester.getSemantics(find.byType(CLTextField));
    data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(data.value, '2');
    expect(data.increasedValue, isEmpty);
    expect(data.decreasedValue, '1');
    semantics.dispose();
  });

  testWidgets('external error keeps text readable and exposes semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(CLTextField(focusNode: focusNode, error: true)),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.style?.color, CLThemeData().colors.textPrimary);
    expect(fieldBorder(tester).color, CLThemeData().colors.danger);
    expect(fieldBorder(tester).width, 1);
    expect(
      tester
          .getSemantics(find.byType(CLTextField))
          .getSemanticsData()
          .validationResult,
      SemanticsValidationResult.invalid,
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(fieldBorder(tester).color, CLThemeData().colors.danger);
    expect(fieldBorder(tester).width, 1.5);

    await tester.pumpWidget(host(const CLTextField()));
    await tester.pumpAndSettle();

    expect(fieldBorder(tester).color.a, 0);
    expect(
      tester
          .getSemantics(find.byType(CLTextField))
          .getSemanticsData()
          .validationResult,
      SemanticsValidationResult.none,
    );
    semantics.dispose();
  });

  testWidgets('invalid numeric input uses a danger outline after blur', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          min: 1,
          max: 10,
        ),
      ),
    );

    Color? textColor() => tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField))
        .style
        ?.color;

    expect(textColor(), CLThemeData().colors.textPrimary);
    expect(fieldBorder(tester).color.a, 0);

    await tester.tap(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '12');
    focusNode.unfocus();
    await tester.pump();

    expect(textColor(), CLThemeData().colors.textPrimary);
    expect(fieldBorder(tester).color, CLThemeData().colors.danger);

    await tester.tap(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '8');
    await tester.pump();

    expect(textColor(), CLThemeData().colors.textPrimary);
    expect(fieldBorder(tester).color, CLThemeData().colors.accent);
  });

  testWidgets('invalid submission is blocked and retains focus', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'invalid');
    final focusNode = FocusNode();
    String? submitted;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          onSubmitted: (value) => submitted = value,
        ),
      ),
    );

    await tester.tap(find.byType(CupertinoTextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, isNull);
    expect(focusNode.hasFocus, isTrue);
    expect(fieldBorder(tester).color, CLThemeData().colors.danger);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .style
          ?.color,
      CLThemeData().colors.textPrimary,
    );

    await tester.enterText(find.byType(CupertinoTextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, '7');
  });
}
