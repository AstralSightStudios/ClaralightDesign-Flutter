import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/cupertino.dart';
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
