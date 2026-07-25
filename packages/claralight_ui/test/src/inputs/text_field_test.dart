import 'dart:ui' show SemanticsAction;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 240, child: child)),
      ),
    );
  }

  final stepUp = find.byKey(const Key('cl-text-field-step-up'));
  final stepDown = find.byKey(const Key('cl-text-field-step-down'));
  final dragZone = find.byKey(const Key('cl-text-field-stepper-drag-zone'));

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

  testWidgets('numeric drag zone preserves geometry and resize cursor', (
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
          size: CLControlSize.small,
        ),
      ),
    );

    final controlRect = tester.getRect(find.byType(CLTextField));
    final zoneRect = tester.getRect(dragZone);
    final upRect = tester.getRect(stepUp);

    expect(zoneRect.width, 24);
    expect(zoneRect.left, upRect.left);
    expect(zoneRect.right, controlRect.right - 1);
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where((region) => region.cursor == SystemMouseCursors.resizeUpDown),
      hasLength(1),
    );

    controller.text = 'invalid';
    await tester.pump();
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where((region) => region.cursor == SystemMouseCursors.resizeUpDown),
      isEmpty,
    );
  });

  testWidgets('mouse scrub is confined to the drag zone and coalesces steps', (
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
          step: 2,
          onChanged: changes.add,
        ),
      ),
    );

    final controlRect = tester.getRect(find.byType(CLTextField));
    final outside = await tester.startGesture(
      Offset(controlRect.center.dx, controlRect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await outside.moveBy(const Offset(0, -24));
    await outside.up();
    await tester.pump();
    expect(controller.text, '10');

    final zoneRect = tester.getRect(dragZone);
    final scrub = await tester.startGesture(
      Offset(zoneRect.right - 2, zoneRect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await scrub.moveBy(const Offset(0, -4));
    await tester.pump();
    expect(controller.text, '10');

    await scrub.moveBy(const Offset(0, -4));
    await tester.pump();
    expect(controller.text, '12');

    await scrub.moveBy(const Offset(0, -17));
    await tester.pump();
    expect(controller.text, '16');
    expect(changes, ['12', '16']);
    expect(focusNode.hasFocus, isTrue);

    await scrub.up();
  });

  testWidgets('horizontal pointer movement does not scrub or click', (
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

    final zoneRect = tester.getRect(dragZone);
    final mouse = await tester.startGesture(
      Offset(zoneRect.right - 2, zoneRect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(20, 4));
    await mouse.up();
    await tester.pump();

    expect(controller.text, '4');
  });

  testWidgets('scrub resets overshoot at bounds for immediate reversal', (
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
          step: 1,
          max: 10,
          onChanged: changes.add,
        ),
      ),
    );

    final zoneRect = tester.getRect(dragZone);
    final mouse = await tester.startGesture(
      zoneRect.center,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -24));
    await tester.pump();
    expect(controller.text, '10');

    await mouse.moveBy(const Offset(0, 8));
    await tester.pump();
    expect(controller.text, '9');
    expect(changes, ['10', '9']);

    await mouse.up();
  });

  testWidgets('stylus scrub uses precise slop and the 8px step threshold', (
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
    await stylus.moveBy(const Offset(0, -7));
    await tester.pump();
    expect(controller.text, '4');

    await stylus.moveBy(const Offset(0, -1));
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
      const Offset(0, -40),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pump();

    expect(controller.text, '4');
  });

  testWidgets('mouse hold repeats at 500ms and switches cleanly to scrub', (
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
    expect(focusNode.hasFocus, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.text, '1');
    expect(focusNode.hasFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.text, '2');

    await mouse.moveBy(const Offset(0, -8));
    await tester.pump();
    expect(controller.text, '3');

    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.text, '3');

    await mouse.up();
    await tester.pump();
    expect(controller.text, '3');
  });

  testWidgets('touch long press activates at 300ms and scrubs with haptic', (
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

    final zoneRect = tester.getRect(dragZone);
    final touch = await tester.startGesture(
      Offset(zoneRect.right - 2, zoneRect.center.dy),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(focusNode.hasFocus, isFalse);
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isEmpty,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(focusNode.hasFocus, isTrue);
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      hasLength(1),
    );
    expect(controller.text, '1');

    await touch.moveBy(const Offset(0, -8));
    await tester.pump();
    expect(controller.text, '2');

    await touch.up();
  });

  testWidgets('touch long press released before repeat does not step', (
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
    await tester.pump(const Duration(milliseconds: 400));
    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, '0');

    await touch.up();
    await tester.pump();
    expect(controller.text, '0');
  });

  testWidgets('touch hold repeats after 500ms without a release step', (
    tester,
  ) async {
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

    final touch = await tester.startGesture(
      tester.getCenter(stepUp),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.text, '0');
    await tester.pump(const Duration(milliseconds: 199));
    expect(controller.text, '0');

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.text, '1');
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.text, '2');

    await touch.up();
    await tester.pump();
    expect(controller.text, '2');
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
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(controller.text, '2');
    expect(focusNode.hasFocus, isFalse);

    node = tester.getSemantics(find.byType(CLTextField));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.increase),
      isFalse,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);
    semantics.dispose();
  });

  testWidgets('external error state turns text red', (tester) async {
    await tester.pumpWidget(host(const CLTextField(error: true)));

    Color? textColor() => tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField))
        .style
        ?.color;

    expect(textColor(), CLThemeData().colors.danger);

    await tester.pumpWidget(host(const CLTextField()));
    await tester.pumpAndSettle();

    expect(textColor(), isNot(CLThemeData().colors.danger));
  });

  testWidgets('invalid numeric input turns red after losing focus', (
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

    expect(textColor(), isNot(CLThemeData().colors.danger));

    await tester.tap(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '12');
    focusNode.unfocus();
    await tester.pump();

    expect(textColor(), CLThemeData().colors.danger);

    await tester.tap(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '8');
    await tester.pump();

    expect(textColor(), isNot(CLThemeData().colors.danger));
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
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .style
          ?.color,
      CLThemeData().colors.danger,
    );

    await tester.enterText(find.byType(CupertinoTextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, '7');
  });
}
