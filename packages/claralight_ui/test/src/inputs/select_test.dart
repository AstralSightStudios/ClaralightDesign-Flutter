import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewportSize = Size(400, 800);

List<CLSelectOption<int>> _options(int count) => [
  for (var index = 0; index < count; index++)
    CLSelectOption(index, 'Option $index'),
];

Finder _panel() =>
    find.byWidgetPredicate((widget) => widget is CLSurface && widget.frosted);

Widget _testApp({
  required List<CLSelectOption<int>> options,
  required int value,
  Alignment alignment = Alignment.center,
  EdgeInsets safePadding = EdgeInsets.zero,
  CLControlSize size = CLControlSize.large,
  bool alignSelectedOption = true,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: _viewportSize,
        padding: safePadding,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: Align(
          alignment: alignment,
          child: CLSelect<int>(
            width: 180,
            size: size,
            options: options,
            value: value,
            onChanged: (_) {},
            alignSelectedOption: alignSelectedOption,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> setViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _viewportSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> openSelect(WidgetTester tester) async {
    await tester.tap(find.byType(CLSelect<int>));
    await tester.pumpAndSettle();
  }

  test('selected option alignment is enabled by default', () {
    final select = CLSelect<int>(
      options: const [CLSelectOption(0, 'Option 0')],
      value: 0,
      onChanged: null,
    );

    expect(select.alignSelectedOption, isTrue);
  });

  for (final alignSelectedOption in [true, false]) {
    testWidgets(
      '${alignSelectedOption ? 'aligned' : 'detached'} panel moves center first and rebounds on close',
      (tester) async {
        await setViewport(tester);
        await tester.pumpWidget(
          _testApp(
            options: _options(5),
            value: 0,
            alignSelectedOption: alignSelectedOption,
          ),
        );
        final triggerFinder = find.descendant(
          of: find.byType(CLSelect<int>),
          matching: find.byType(CLPressable),
        );
        final triggerRect = tester.getRect(triggerFinder);

        await tester.tap(find.byType(CLSelect<int>));
        await tester.pump();
        final initialPanelRect = tester.getRect(_panel());
        expect(
          initialPanelRect.center.dx,
          closeTo(triggerRect.center.dx, 0.01),
        );
        expect(
          initialPanelRect.center.dy,
          closeTo(triggerRect.center.dy, 0.01),
        );
        expect(initialPanelRect.size, triggerRect.size);

        await tester.pump(const Duration(milliseconds: 80));
        final partialPanelRect = tester.getRect(_panel());
        await tester.pump(const Duration(milliseconds: 40));
        final latePanelRect = tester.getRect(_panel());
        await tester.pumpAndSettle();
        final settledPanelRect = tester.getRect(_panel());
        final totalTravel = settledPanelRect.center - triggerRect.center;
        final partialTravel = partialPanelRect.center - triggerRect.center;
        final lateTravel = latePanelRect.center - triggerRect.center;
        final centerProgress =
            (partialTravel.dx * totalTravel.dx +
                partialTravel.dy * totalTravel.dy) /
            totalTravel.distanceSquared;
        final lateCenterProgress =
            (lateTravel.dx * totalTravel.dx + lateTravel.dy * totalTravel.dy) /
            totalTravel.distanceSquared;
        final morphProgress =
            (partialPanelRect.height - triggerRect.height) /
            (settledPanelRect.height - triggerRect.height);
        final lateMorphProgress =
            (latePanelRect.height - triggerRect.height) /
            (settledPanelRect.height - triggerRect.height);

        expect(centerProgress, greaterThan(0.65));
        expect(centerProgress, lessThan(1));
        expect(morphProgress, greaterThan(0.1));
        expect(morphProgress, lessThan(0.25));
        expect(centerProgress, greaterThan(morphProgress + 0.45));
        expect(lateCenterProgress, greaterThan(1.03));
        expect(lateCenterProgress, lessThan(1.15));
        expect(lateMorphProgress, greaterThan(0.45));
        expect(lateMorphProgress, lessThan(0.8));

        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        final handoffTriggerRect = tester.getRect(triggerFinder);
        final handoffPanelRect = tester.getRect(_panel());
        final handoffTravel = handoffTriggerRect.center - triggerRect.center;
        final handoffProgress =
            (handoffTravel.dx * totalTravel.dx +
                handoffTravel.dy * totalTravel.dy) /
            totalTravel.distanceSquared;
        expect(handoffProgress, lessThan(0));
        expect(
          handoffPanelRect.center.dx,
          closeTo(handoffTriggerRect.center.dx, 0.05),
        );
        expect(
          handoffPanelRect.center.dy,
          closeTo(handoffTriggerRect.center.dy, 0.05),
        );

        await tester.pump(const Duration(milliseconds: 40));
        final reboundTriggerRect = tester.getRect(triggerFinder);
        final reboundTravel = reboundTriggerRect.center - triggerRect.center;
        final closeProgress =
            (reboundTravel.dx * totalTravel.dx +
                reboundTravel.dy * totalTravel.dy) /
            totalTravel.distanceSquared;
        expect(closeProgress, greaterThan(-0.1));
        expect(closeProgress, lessThan(-0.07));

        await tester.pumpAndSettle();
        expect(_panel(), findsNothing);
        expect(tester.getRect(triggerFinder), triggerRect);
      },
    );
  }

  testWidgets('reduced motion snaps geometry and keeps only the fade', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(
      _testApp(options: _options(5), value: 0, disableAnimations: true),
    );
    final triggerRect = tester.getRect(find.byType(CLSelect<int>));

    await tester.tap(find.byType(CLSelect<int>));
    await tester.pump();
    final initialPanelRect = tester.getRect(_panel());
    expect(initialPanelRect.height, greaterThan(triggerRect.height));
    expect(
      initialPanelRect.center.dy,
      isNot(closeTo(triggerRect.center.dy, 0.01)),
    );

    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getRect(_panel()), initialPanelRect);
    final panelOpacity = tester.widget<Opacity>(
      find.ancestor(of: _panel(), matching: find.byType(Opacity)),
    );
    expect(panelOpacity.opacity, greaterThan(0));
    expect(panelOpacity.opacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.getRect(_panel()), initialPanelRect);
  });

  for (final (size, expectedHeight) in [
    (CLControlSize.small, 28.0),
    (CLControlSize.medium, 36.0),
    (CLControlSize.large, 44.0),
  ]) {
    testWidgets('$size option items match the trigger size', (tester) async {
      await setViewport(tester);
      await tester.pumpWidget(
        _testApp(options: _options(5), value: 2, size: size),
      );

      final triggerRect = tester.getRect(find.byType(CLSelect<int>));
      await openSelect(tester);

      final selectedLabel = find.descendant(
        of: find.byType(CLList),
        matching: find.text('Option 2'),
      );
      final selectedItem = find.ancestor(
        of: selectedLabel,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is MouseRegion &&
              widget.cursor == SystemMouseCursors.click,
        ),
      );
      expect(selectedItem, findsOneWidget);

      final itemRect = tester.getRect(selectedItem);
      expect(itemRect.width, triggerRect.width);
      expect(itemRect.left, triggerRect.left);
      expect(itemRect.right, triggerRect.right);
      expect(itemRect.height, expectedHeight);
      expect(itemRect.height, triggerRect.height);
    });
  }

  testWidgets('selected option is centered on the field when opened', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(_testApp(options: _options(5), value: 2));

    final fieldCenter = tester.getCenter(find.byType(CLSelect<int>));
    await openSelect(tester);

    final selectedLabel = find.descendant(
      of: find.byType(CLList),
      matching: find.text('Option 2'),
    );
    expect(selectedLabel, findsOneWidget);
    expect(tester.getCenter(selectedLabel).dy, closeTo(fieldCenter.dy, 0.01));
  });

  testWidgets('long list stays inside safe area and scrolls to selection', (
    tester,
  ) async {
    await setViewport(tester);
    const safePadding = EdgeInsets.only(top: 24, bottom: 34);
    await tester.pumpWidget(
      _testApp(options: _options(50), value: 25, safePadding: safePadding),
    );

    final fieldCenter = tester.getCenter(find.byType(CLSelect<int>));
    await openSelect(tester);

    final listFinder = find.byType(CLList);
    final listRect = tester.getRect(listFinder);
    expect(listRect.top, greaterThanOrEqualTo(safePadding.top + 8));
    expect(
      listRect.bottom,
      lessThanOrEqualTo(_viewportSize.height - safePadding.bottom - 8),
    );

    final list = tester.widget<CLList>(listFinder);
    expect(list.controller, isNotNull);
    expect(list.controller!.offset, greaterThan(0));

    final selectedLabel = find.descendant(
      of: listFinder,
      matching: find.text('Option 25'),
    );
    expect(selectedLabel, findsOneWidget);
    expect(tester.getCenter(selectedLabel).dy, closeTo(fieldCenter.dy, 0.01));
  });

  testWidgets('panel is shifted inside horizontal safe bounds', (tester) async {
    await setViewport(tester);
    const safePadding = EdgeInsets.only(left: 20, right: 30);
    await tester.pumpWidget(
      _testApp(
        options: _options(5),
        value: 2,
        alignment: Alignment.centerRight,
        safePadding: safePadding,
      ),
    );

    await openSelect(tester);

    final listRect = tester.getRect(find.byType(CLList));
    expect(listRect.left, greaterThanOrEqualTo(safePadding.left + 8));
    expect(
      listRect.right,
      lessThanOrEqualTo(_viewportSize.width - safePadding.right - 8),
    );
  });

  testWidgets('safe area wins when exact selected alignment is impossible', (
    tester,
  ) async {
    await setViewport(tester);
    const safePadding = EdgeInsets.only(top: 24, bottom: 34);
    await tester.pumpWidget(
      _testApp(
        options: _options(10),
        value: 8,
        alignment: Alignment.bottomCenter,
        safePadding: safePadding,
      ),
    );

    final fieldCenter = tester.getCenter(find.byType(CLSelect<int>));
    await openSelect(tester);

    final listFinder = find.byType(CLList);
    final listRect = tester.getRect(listFinder);
    expect(
      listRect.bottom,
      lessThanOrEqualTo(_viewportSize.height - safePadding.bottom - 8),
    );

    final selectedLabel = find.descendant(
      of: listFinder,
      matching: find.text('Option 8'),
    );
    expect(selectedLabel, findsOneWidget);
    expect(tester.getCenter(selectedLabel).dy, lessThan(fieldCenter.dy));
  });

  testWidgets('disabled alignment opens below for a valid value', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(
      _testApp(options: _options(3), value: 1, alignSelectedOption: false),
    );

    final fieldRect = tester.getRect(find.byType(CLSelect<int>));
    await openSelect(tester);

    final listRect = tester.getRect(find.byType(CLList));
    expect(listRect.top, closeTo(fieldRect.bottom + 5, 0.01));
  });

  testWidgets('disabled alignment opens above near the bottom', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(
      _testApp(
        options: _options(3),
        value: 1,
        alignment: Alignment.bottomCenter,
        alignSelectedOption: false,
      ),
    );

    final fieldRect = tester.getRect(find.byType(CLSelect<int>));
    await openSelect(tester);

    final listRect = tester.getRect(find.byType(CLList));
    expect(listRect.bottom, closeTo(fieldRect.top - 5, 0.01));
  });

  testWidgets('invalid value keeps the below-field fallback', (tester) async {
    await setViewport(tester);
    await tester.pumpWidget(_testApp(options: _options(3), value: 99));

    final fieldRect = tester.getRect(find.byType(CLSelect<int>));
    await openSelect(tester);

    final listRect = tester.getRect(find.byType(CLList));
    // CLList sits one pixel inside the outlined panel.
    expect(listRect.top, closeTo(fieldRect.bottom + 5, 0.01));
  });

  testWidgets('ghost variant uses transparent background and right alignment by default', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLSelect<int>(
            variant: CLSelectVariant.ghost,
            options: const [CLSelectOption(0, 'Ghost Label')],
            value: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(find.text('Ghost Label'));
    expect(textWidget.textAlign, TextAlign.right);

    final surfaceFinder = find.ancestor(
      of: find.text('Ghost Label'),
      matching: find.byType(CLSurface),
    );
    final surfaceRect = tester.getRect(surfaceFinder);
    expect(surfaceRect.height, equals(CLControlSize.large.controlHeight));
  });

  testWidgets('selected option row highlights with accentBackground and accent text', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(
      _testApp(options: _options(3), value: 1),
    );

    await openSelect(tester);

    final selectedLabel = find.descendant(
      of: find.byType(CLList),
      matching: find.text('Option 1'),
    );
    final selectedText = tester.widget<Text>(selectedLabel);
    final theme = CLTheme.of(tester.element(selectedLabel));
    expect(selectedText.style?.color, theme.colors.accent);
  });

  testWidgets('panel expands wider than trigger when options contain long text', (
    tester,
  ) async {
    await setViewport(tester);
    await tester.pumpWidget(
      _testApp(
        options: const [
          CLSelectOption(0, 'Short'),
          CLSelectOption(1, 'A Very Long Option Label That Exceeds Trigger Width'),
        ],
        value: 0,
      ),
    );

    final triggerRect = tester.getRect(find.byType(CLSelect<int>));
    await openSelect(tester);

    final panelRect = tester.getRect(_panel());
    expect(panelRect.width, greaterThan(triggerRect.width));
  });

  testWidgets('trigger text updates immediately on tap and close animation settles cleanly', (
    tester,
  ) async {
    await setViewport(tester);
    int selectedValue = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: CLSelect<int>(
                  variant: CLSelectVariant.ghost,
                  options: const [
                    CLSelectOption(0, '00:00'),
                    CLSelectOption(1, '00:00:00 Extra Long Value'),
                  ],
                  value: selectedValue,
                  onChanged: (v) => setState(() => selectedValue = v),
                ),
              ),
            ),
          );
        },
      ),
    );

    final surfaceFinder = find.descendant(
      of: find.byType(CLSelect<int>),
      matching: find.byType(CLSurface),
    ).first;
    final initialTriggerRect = tester.getRect(surfaceFinder);
    await openSelect(tester);

    final longOption = find.descendant(
      of: find.byType(CLList),
      matching: find.text('00:00:00 Extra Long Value'),
    );
    await tester.tap(longOption);
    await tester.pump(); // Start close animation frame 1

    // Trigger text & width update immediately on selection
    final midClosingTriggerRect = tester.getRect(surfaceFinder);
    expect(midClosingTriggerRect.width, greaterThan(initialTriggerRect.width));
    expect(find.text('00:00:00 Extra Long Value'), findsNWidgets(2)); // Trigger + Overlay

    // Finish close animation
    await tester.pumpAndSettle();
    final finalTriggerRect = tester.getRect(surfaceFinder);
    expect(finalTriggerRect.width, greaterThan(initialTriggerRect.width));
    expect(find.text('00:00:00 Extra Long Value'), findsOneWidget); // Trigger only
  });

  testWidgets('standard variant morphs back to full trigger width on close', (
    tester,
  ) async {
    await setViewport(tester);
    int selectedValue = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 250,
                child: CLSelect<int>(
                  variant: CLSelectVariant.standard,
                  options: const [
                    CLSelectOption(0, 'A'),
                    CLSelectOption(1, 'B'),
                  ],
                  value: selectedValue,
                  onChanged: (v) => setState(() => selectedValue = v),
                ),
              ),
            ),
          );
        },
      ),
    );

    final triggerRect = tester.getRect(find.byType(CLSelect<int>));
    expect(triggerRect.width, equals(250.0));

    await openSelect(tester);

    final optionB = find.descendant(
      of: find.byType(CLList),
      matching: find.text('B'),
    );
    await tester.tap(optionB);
    await tester.pump(); // Start close animation

    // Target closing width for fixed/standard select must remain full 250px
    final surfaceFinder = find.descendant(
      of: find.byType(CLSelect<int>),
      matching: find.byType(CLSurface),
    ).first;
    final closingTriggerRect = tester.getRect(surfaceFinder);
    expect(closingTriggerRect.width, equals(250.0));

    await tester.pumpAndSettle();
  });
}
