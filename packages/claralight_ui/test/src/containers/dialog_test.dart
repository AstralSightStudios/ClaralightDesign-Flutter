import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dialogContentKey = Key('dialog-content');

void main() {
  Widget hostWithActions(int actionCount) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CLDialog(
            maxWidth: 400,
            actions: [
              for (var i = 0; i < actionCount; i++)
                SizedBox(key: Key('action-$i'), height: 44),
            ],
            child: const SizedBox(width: 200, height: 40),
          ),
        ),
      ),
    );
  }

  Rect actionRect(WidgetTester tester, int index) {
    return tester.getRect(find.byKey(Key('action-$index')));
  }

  test('defaults to a compact 320px maximum width', () {
    expect(const CLDialog(child: SizedBox()).maxWidth, 320);
  });

  testWidgets('show uses the compact default width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                child: const SizedBox(width: 500, height: 40),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();

    expect(tester.widget<CLDialog>(find.byType(CLDialog)).maxWidth, 320);
    expect(tester.getSize(find.byType(CLDialog)).width, 320);
  });

  testWidgets('static trigger rect remains the dismissal target', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const triggerRect = Rect.fromLTWH(20, 20, 100, 40);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(triggerRect),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();

    final route = ModalRoute.of(tester.element(find.byKey(_dialogContentKey)))!;
    expect(route.transitionDuration, const Duration(milliseconds: 380));
    expect(route.reverseTransitionDuration, CLMotion.standard);

    await tester.pump(const Duration(milliseconds: 380));
    await tester.tapAt(const Offset(10, 590));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final dismissingCenter = tester.getRect(find.byType(CLDialog)).center;
    expect(
      (dismissingCenter - triggerRect.center).distance,
      lessThan((dismissingCenter - const Offset(400, 300)).distance),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('dismissal remeasures a moved trigger context', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var triggerLeft = 24.0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Stack(
                children: [
                  Positioned(
                    left: triggerLeft,
                    top: 24,
                    child: Builder(
                      builder: (triggerContext) => TextButton(
                        key: const Key('moving-trigger'),
                        onPressed: () => CLDialog.show<void>(
                          context,
                          trigger: CLDialogTrigger.capture(triggerContext),
                          child: const Text(
                            'Dialog body',
                            key: _dialogContentKey,
                          ),
                        ),
                        child: const Text('Open dialog'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final trigger = find.byKey(const Key('moving-trigger'));
    final originalCenter = tester.getRect(trigger).center;
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    setHostState(() => triggerLeft = 640);
    await tester.pump();
    final movedCenter = tester.getRect(trigger).center;
    expect(movedCenter.dx, greaterThan(originalCenter.dx + 500));

    await tester.tapAt(const Offset(10, 590));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final dismissingCenter = tester.getRect(find.byType(CLDialog)).center;
    expect(
      (dismissingCenter - movedCenter).distance,
      lessThan((dismissingCenter - originalCenter).distance),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('dismissal ignores a disposed trigger context', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var showTrigger = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return showTrigger
                  ? Builder(
                      builder: (triggerContext) => TextButton(
                        onPressed: () => CLDialog.show<void>(
                          context,
                          trigger: CLDialogTrigger.capture(triggerContext),
                          child: const Text(
                            'Dialog body',
                            key: _dialogContentKey,
                          ),
                        ),
                        child: const Text('Open dialog'),
                      ),
                    )
                  : const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    setHostState(() => showTrigger = false);
    await tester.pump();

    final dialog = find.byType(CLDialog);
    await tester.tapAt(const Offset(10, 590));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.getRect(dialog).center, const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('reduced motion skips morph and keeps a short fade', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(
                  Rect.fromLTWH(20, 20, 100, 40),
                ),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();

    final dialog = find.byType(CLDialog);
    final route = ModalRoute.of(tester.element(dialog))!;
    final opacity = find
        .ancestor(of: dialog, matching: find.byType(Opacity))
        .first;

    expect(route.transitionDuration, CLMotion.reducedFade);
    expect(route.reverseTransitionDuration, CLMotion.reducedFade);
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(tester.widget<Opacity>(opacity).opacity, 0);

    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(tester.widget<Opacity>(opacity).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(1, 0.001));

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(tester.widget<Opacity>(opacity).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('enabling reduced motion snaps an in-flight morph', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final reducedMotion = ValueNotifier(false);
    addTearDown(reducedMotion.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: reducedMotion,
          child: child,
          builder: (context, disableAnimations, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(
                  Rect.fromLTWH(20, 20, 100, 40),
                ),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final dialog = find.byType(CLDialog);
    final opacity = find
        .ancestor(of: dialog, matching: find.byType(Opacity))
        .first;
    expect(
      (tester.getRect(dialog).center - const Offset(400, 300)).distance,
      greaterThan(20),
    );
    final handoffOpacity = tester.widget<Opacity>(opacity).opacity;

    reducedMotion.value = true;
    await tester.pump();

    final route = ModalRoute.of(tester.element(dialog))!;
    expect(route.transitionDuration, CLMotion.reducedFade);
    expect(route.reverseTransitionDuration, CLMotion.reducedFade);
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(
      tester.widget<Opacity>(opacity).opacity,
      closeTo(handoffOpacity, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 62));
    final midFadeOpacity = tester.widget<Opacity>(opacity).opacity;
    expect(midFadeOpacity, greaterThan(handoffOpacity));
    expect(midFadeOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(1, 0.001));
    expect(tester.getRect(dialog).center, const Offset(400, 300));
  });

  testWidgets('enabling reduced motion snaps an in-flight dismissal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final reducedMotion = ValueNotifier(false);
    addTearDown(reducedMotion.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: reducedMotion,
          child: child,
          builder: (context, disableAnimations, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(
                  Rect.fromLTWH(20, 20, 100, 40),
                ),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final dialog = find.byType(CLDialog);
    final opacity = find
        .ancestor(of: dialog, matching: find.byType(Opacity))
        .first;
    final handoffOpacity = tester.widget<Opacity>(opacity).opacity;
    expect(handoffOpacity, greaterThan(0));

    reducedMotion.value = true;
    await tester.pump();

    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(
      tester.widget<Opacity>(opacity).opacity,
      closeTo(handoffOpacity, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 62));
    final midFadeOpacity = tester.widget<Opacity>(opacity).opacity;
    expect(midFadeOpacity, greaterThan(0));
    expect(midFadeOpacity, lessThan(handoffOpacity));

    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('platform reduced motion overrides a fixed MediaQuery', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(
                  Rect.fromLTWH(20, 20, 100, 40),
                ),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final dialog = find.byType(CLDialog);
    final opacity = find
        .ancestor(of: dialog, matching: find.byType(Opacity))
        .first;
    final handoffOpacity = tester.widget<Opacity>(opacity).opacity;
    expect(
      (tester.getRect(dialog).center - const Offset(400, 300)).distance,
      greaterThan(20),
    );

    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();

    final route = ModalRoute.of(tester.element(dialog))!;
    expect(route.transitionDuration, CLMotion.reducedFade);
    expect(route.reverseTransitionDuration, CLMotion.reducedFade);
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(
      tester.widget<Opacity>(opacity).opacity,
      closeTo(handoffOpacity, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 62));
    final midFadeOpacity = tester.widget<Opacity>(opacity).opacity;
    expect(midFadeOpacity, greaterThan(handoffOpacity));
    expect(midFadeOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(1, 0.001));
  });

  testWidgets('platform reduced motion rebuilds a settled dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                trigger: const CLDialogTrigger.fixed(
                  Rect.fromLTWH(20, 20, 100, 40),
                ),
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));

    final dialog = find.byType(CLDialog);
    final opacity = find
        .ancestor(of: dialog, matching: find.byType(Opacity))
        .first;
    expect(
      find.ancestor(of: dialog, matching: find.byType(Center)),
      findsNothing,
    );

    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();

    final route = ModalRoute.of(tester.element(dialog))!;
    expect(route.transitionDuration, CLMotion.reducedFade);
    expect(route.reverseTransitionDuration, CLMotion.reducedFade);
    expect(
      find.ancestor(of: dialog, matching: find.byType(Center)),
      findsOneWidget,
    );
    expect(tester.widget<Opacity>(opacity).opacity, 1);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getRect(dialog).center, const Offset(400, 300));
    expect(tester.widget<Opacity>(opacity).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('can be interrupted mid-flight by tapping barrier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    // Advance just 50ms into 380ms transition (mid-flight)
    await tester.pump(const Duration(milliseconds: 50));

    // Tap background scrim barrier to interrupt mid-flight
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(_dialogContentKey), findsNothing);
  });

  testWidgets('show accepts a captured trigger', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (buttonContext) => TextButton(
              onPressed: () => CLDialog.show<void>(
                buttonContext,
                trigger: CLDialogTrigger.capture(buttonContext),
                child: const Text('Dialog body'),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));

    expect(find.text('Dialog body'), findsOneWidget);
  });

  testWidgets('select overlay stays inside safe area when shown in a dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const safePadding = EdgeInsets.fromLTRB(20, 48, 30, 34);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: safePadding, viewPadding: safePadding),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                child: CLSelect<int>(
                  width: 180,
                  options: [
                    for (var index = 0; index < 50; index++)
                      CLSelectOption(index, 'Option $index'),
                  ],
                  value: 25,
                  onChanged: (_) {},
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(find.byType(CLList), findsOneWidget);
    final listRect = tester.getRect(find.byType(CLList));
    expect(listRect.left, greaterThanOrEqualTo(safePadding.left + 8));
    expect(listRect.top, greaterThanOrEqualTo(safePadding.top + 8));
    expect(listRect.right, lessThanOrEqualTo(400 - safePadding.right - 8));
    expect(listRect.bottom, lessThanOrEqualTo(800 - safePadding.bottom - 8));
  });

  testWidgets('lays out two actions horizontally with equal widths', (
    tester,
  ) async {
    await tester.pumpWidget(hostWithActions(2));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);

    expect(first.center.dy, second.center.dy);
    expect(second.left - first.right, 10);
    expect(first.width, second.width);
  });

  testWidgets('stacks three actions vertically at full width', (tester) async {
    await tester.pumpWidget(hostWithActions(3));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);
    final third = actionRect(tester, 2);

    expect(first.center.dx, second.center.dx);
    expect(second.center.dx, third.center.dx);
    expect(second.top - first.bottom, 10);
    expect(third.top - second.bottom, 10);
    expect(first.width, second.width);
    expect(second.width, third.width);
  });
}
