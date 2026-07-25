import 'dart:ui' show SemanticsValidationResult, Tristate;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progressive_blur/progressive_blur.dart';

void main() {
  Widget host(
    Widget child, {
    bool disableAnimations = false,
    double textScale = 1,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Directionality(
            textDirection: textDirection,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 280, child: child),
            ),
          ),
        ),
      ),
    );
  }

  BorderSide surfaceBorder(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byKey(const Key('cl-text-area-surface')),
    );
    final decoration = container.decoration! as ShapeDecoration;
    return (decoration.shape as RoundedSuperellipseBorder).side;
  }

  ProgressiveBlurWidget edgeEffect(WidgetTester tester) =>
      tester.widget<ProgressiveBlurWidget>(find.byType(ProgressiveBlurWidget));

  RenderEditable renderEditable(WidgetTester tester) {
    RenderEditable? result;

    void visit(RenderObject object) {
      if (object case final RenderEditable editable) {
        result = editable;
        return;
      }
      object.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(EditableText)));
    return result!;
  }

  Rect globalCaretRect(WidgetTester tester, TextPosition position) {
    final editable = renderEditable(tester);
    final localRect = editable.getLocalRectForCaret(position);
    return Rect.fromPoints(
      editable.localToGlobal(localRect.topLeft),
      editable.localToGlobal(localRect.bottomRight),
    );
  }

  setUpAll(CLTextArea.precache);

  testWidgets('defaults to a fixed 120px multiline field', (tester) async {
    await tester.pumpWidget(host(const CLTextArea(placeholder: 'Description')));

    expect(tester.getSize(find.byType(CLTextArea)).height, 120);
    expect(find.byType(RawScrollbar), findsOneWidget);
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(CupertinoScrollbar), findsNothing);

    final scrollable = tester.widget<CLScrollable>(find.byType(CLScrollable));
    expect(scrollable.direction, CLScrollDirection.vertical);
    expect(scrollable.blurExtent, const EdgeInsets.symmetric(vertical: 24));
    expect(scrollable.blurSigma, const EdgeInsets.symmetric(vertical: 5));
    expect(scrollable.horizontalScrollbar, CLScrollbarVisibility.hidden);
    expect(scrollable.verticalScrollbar, CLScrollbarVisibility.auto);
    expect(scrollable.padding, const EdgeInsets.all(12));
    expect(
      tester.getRect(find.byType(CLScrollable)),
      tester.getRect(find.byKey(const Key('cl-text-area-surface'))).deflate(1),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.minLines, 1);
    expect(field.maxLines, isNull);
    expect(field.textInputAction, isNull);
    expect(field.placeholder, 'Description');
    expect(field.style?.color, CLThemeData().colors.textPrimary);
    expect(field.scrollController, isNull);
    expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('suppresses the desktop EditableText scrollbar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final controller = TextEditingController(
        text: List.generate(20, (index) => 'Line $index').join('\n'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(host(CLTextArea(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(RawScrollbar), findsOneWidget);
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(CupertinoScrollbar), findsNothing);
      final scrollbar = tester.widget<RawScrollbar>(
        find.byKey(const ValueKey<Axis>(Axis.vertical)),
      );
      expect(scrollbar.thickness, 4);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('control sizes select dense and body typography', (tester) async {
    final typography = CLThemeData().typography;

    for (final size in CLControlSize.values) {
      await tester.pumpWidget(host(CLTextArea(size: size)));
      final style = tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .style;
      expect(
        style?.fontSize,
        size == CLControlSize.large
            ? typography.body.fontSize
            : typography.callout.fontSize,
      );
      expect(tester.getSize(find.byType(CLTextArea)).height, 120);
    }
  });

  testWidgets('fixed height scrolls overflowing content', (tester) async {
    final controller = TextEditingController();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(controller: controller, scrollController: scrollController),
      ),
    );

    controller.text = List.generate(20, (index) => 'Line $index').join('\n');
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(CLTextArea)).height, 120);
    expect(scrollController.hasClients, isTrue);
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('overflow activates bottom then top progressive blur', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: List.generate(20, (index) => 'Line $index').join('\n'),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(controller: controller, scrollController: scrollController),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProgressiveBlurWidget), findsOneWidget);
    var activations = edgeEffect(tester).layerActivations!;
    expect(activations.layer1, 0);
    expect(activations.layer3, 1);
    expect(edgeEffect(tester).maskAlpha, isTrue);

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pumpAndSettle();

    activations = edgeEffect(tester).layerActivations!;
    expect(activations.layer1, 1);
    expect(activations.layer3, 0);
  });

  testWidgets('caret and selection extent respect scroll content padding', (
    tester,
  ) async {
    final text = List.generate(20, (index) => 'Line $index').join('\n');
    final controller = TextEditingController(text: text)
      ..selection = const TextSelection.collapsed(offset: 0);
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    controller.selection = TextSelection.collapsed(offset: text.length);
    await tester.pumpAndSettle();

    final scrollableRect = tester.getRect(find.byType(CLScrollable));
    var caretRect = globalCaretRect(tester, controller.selection.extent);
    expect(scrollController.offset, greaterThan(0));
    expect(
      scrollableRect.bottom - caretRect.bottom,
      greaterThanOrEqualTo(11.5),
    );

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    await tester.pumpAndSettle();

    caretRect = globalCaretRect(tester, controller.selection.extent);
    expect(
      scrollableRect.bottom - caretRect.bottom,
      greaterThanOrEqualTo(11.5),
    );
  });

  testWidgets('auto growth animates between pixel height limits', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(CLTextArea(controller: controller, minHeight: 80, maxHeight: 200)),
    );
    expect(tester.getSize(find.byType(CLTextArea)).height, 80);

    controller.text = List.filled(5, 'Growing line').join('\n');
    await tester.pump();
    expect(tester.getSize(find.byType(CLTextArea)).height, 80);

    await tester.pump(const Duration(milliseconds: 70));
    final growingHeight = tester.getSize(find.byType(CLTextArea)).height;
    expect(growingHeight, greaterThan(80));
    expect(growingHeight, lessThan(200));

    await tester.pumpAndSettle();
    final grownHeight = tester.getSize(find.byType(CLTextArea)).height;
    expect(grownHeight, greaterThan(growingHeight));
    expect(grownHeight, lessThan(200));

    controller.text = List.filled(20, 'Overflowing line').join('\n');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CLTextArea)).height, 200);

    controller.clear();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final shrinkingHeight = tester.getSize(find.byType(CLTextArea)).height;
    expect(shrinkingHeight, greaterThan(80));
    expect(shrinkingHeight, lessThan(200));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CLTextArea)).height, 80);
  });

  testWidgets('reduced motion snaps auto growth to the target height', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(controller: controller, minHeight: 80, maxHeight: 200),
        disableAnimations: true,
      ),
    );

    controller.text = List.filled(5, 'Growing line').join('\n');
    await tester.pump();

    expect(tester.getSize(find.byType(CLTextArea)).height, greaterThan(80));
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('cl-text-area-surface')),
          )
          .duration,
      Duration.zero,
    );
  });

  testWidgets('placeholder drives auto growth', (tester) async {
    const multiline = 'One\nTwo\nThree';

    await tester.pumpWidget(
      host(
        const CLTextArea(placeholder: multiline, minHeight: 80, maxHeight: 200),
      ),
    );
    await tester.pumpAndSettle();
    final placeholderHeight = tester.getSize(find.byType(CLTextArea)).height;
    expect(placeholderHeight, closeTo(84, 0.01));

    final controller = TextEditingController(text: multiline);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(CLTextArea(controller: controller, minHeight: 80, maxHeight: 200)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CLTextArea)).height,
      closeTo(placeholderHeight, 0.01),
    );
  });

  testWidgets('external error uses a persistent danger outline', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(CLTextArea(focusNode: focusNode, error: true)),
    );

    expect(surfaceBorder(tester).color, CLThemeData().colors.danger);
    expect(surfaceBorder(tester).width, 1);
    expect(
      tester
          .getSemantics(find.byType(CLTextArea))
          .getSemanticsData()
          .validationResult,
      SemanticsValidationResult.invalid,
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(surfaceBorder(tester).color, CLThemeData().colors.danger);
    expect(surfaceBorder(tester).width, 1.5);
    semantics.dispose();
  });

  testWidgets('readOnly remains focusable and selectable but not editable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: 'Selectable text');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(
          controller: controller,
          focusNode: focusNode,
          readOnly: true,
        ),
      ),
    );

    await tester.tap(find.byType(CLTextArea));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(
      tester
          .getSemantics(find.byType(CLTextArea))
          .getSemanticsData()
          .flagsCollection
          .isReadOnly,
      isTrue,
    );

    await tester.enterText(find.byType(CupertinoTextField), 'Changed');
    await tester.pump();
    expect(controller.text, 'Selectable text');
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .enableInteractiveSelection,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('readOnly scrolls while disabled blocks interaction', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: List.generate(20, (index) => 'Line $index').join('\n'),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    Widget field({required bool enabled}) => host(
      CLTextArea(
        controller: controller,
        scrollController: scrollController,
        enabled: enabled,
        readOnly: true,
      ),
    );

    await tester.pumpWidget(field(enabled: true));
    await tester.pumpAndSettle();
    final position = tester.getCenter(find.byType(CLTextArea));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, 60),
      ),
    );
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));

    await tester.pumpWidget(field(enabled: false));
    await tester.pumpAndSettle();
    scrollController.jumpTo(0);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: position,
        scrollDelta: const Offset(0, 60),
      ),
    );
    await tester.pump();
    expect(scrollController.offset, 0);
  });

  testWidgets('disabling a focused field clears focus styling', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(host(CLTextArea(focusNode: focusNode)));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(surfaceBorder(tester).color, CLThemeData().colors.accent);
    expect(surfaceBorder(tester).width, 1.5);

    await tester.pumpWidget(
      host(CLTextArea(focusNode: focusNode, enabled: false)),
    );
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(surfaceBorder(tester).color.a, 0);
    expect(surfaceBorder(tester).width, 1);
  });

  testWidgets('disabled state suppresses errors and interaction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      host(CLTextArea(focusNode: focusNode, enabled: false, error: true)),
    );

    await tester.tap(find.byType(CLTextArea));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(surfaceBorder(tester).color.a, 0);
    expect(
      tester
          .getSemantics(find.byType(CLTextArea))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(find.byType(CLTextArea))
          .getSemanticsData()
          .validationResult,
      SemanticsValidationResult.none,
    );
    semantics.dispose();
  });

  testWidgets('passes practical text input configuration and callbacks', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Draft');
    String? submitted;
    addTearDown(controller.dispose);
    final formatter = FilteringTextInputFormatter.allow(RegExp('[A-Z]'));

    await tester.pumpWidget(
      host(
        CLTextArea(
          controller: controller,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [formatter],
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          onSubmitted: (value) => submitted = value,
        ),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.keyboardType, TextInputType.name);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.textCapitalization, TextCapitalization.words);
    expect(field.inputFormatters, [formatter]);
    expect(field.autofocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textAlign, TextAlign.center);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, 'Draft');
  });

  testWidgets('swaps external controllers without disposing caller state', (
    tester,
  ) async {
    final firstText = TextEditingController(text: 'One');
    final secondText = TextEditingController(text: 'Second');
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    final firstScroll = ScrollController();
    final secondScroll = ScrollController();
    addTearDown(firstText.dispose);
    addTearDown(secondText.dispose);
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);
    addTearDown(firstScroll.dispose);
    addTearDown(secondScroll.dispose);

    await tester.pumpWidget(
      host(
        CLTextArea(
          controller: firstText,
          focusNode: firstFocus,
          scrollController: firstScroll,
        ),
      ),
    );

    await tester.pumpWidget(
      host(
        CLTextArea(
          controller: secondText,
          focusNode: secondFocus,
          scrollController: secondScroll,
        ),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.controller, same(secondText));
    expect(field.focusNode, same(secondFocus));
    expect(field.scrollController, isNull);
    expect(secondScroll.hasClients, isTrue);
    expect(
      tester.widget<CLScrollable>(find.byType(CLScrollable)).verticalController,
      same(secondScroll),
    );

    firstText.text = 'Detached controller';
    await tester.pump();
    expect(secondText.text, 'Second');

    await tester.pumpWidget(const SizedBox.shrink());
    secondText.text = 'Still owned by caller';
    void listener() {}

    secondScroll.addListener(listener);
    secondScroll.removeListener(listener);
  });

  test('validates height, width, and radius inputs', () {
    expect(() => CLTextArea(minHeight: 0), throwsAssertionError);
    expect(
      () => CLTextArea(minHeight: 120, maxHeight: 100),
      throwsAssertionError,
    );
    expect(() => CLTextArea(width: double.infinity), throwsAssertionError);
    expect(() => CLTextArea(borderRadius: -1), throwsAssertionError);
  });
}
