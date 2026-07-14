import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  late Duration originalUpdateInterval;

  setUpAll(() {
    originalUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  Widget host(
    Widget child, {
    double width = 120,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  double translationX(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(CLMarqueeText),
        matching: find.byType(Transform),
      ),
    );
    return transform.transform.getTranslation().x;
  }

  testWidgets('short text remains static', (tester) async {
    await tester.pumpWidget(host(const CLMarqueeText('Short')));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Short'), findsOneWidget);
    expect(find.bySemanticsLabel('Short'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CLMarqueeText),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('overflowing text waits then loops at 30 px/s with a 32px gap', (
    tester,
  ) async {
    const text = 'A deliberately long device name';
    await tester.pumpWidget(host(const CLMarqueeText(text)));
    await tester.pump();

    final labels = find.text(text);
    expect(labels, findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(CLMarqueeText),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 32,
        ),
      ),
      findsOneWidget,
    );
    final viewportLeft = tester.getTopLeft(find.byType(ClipRect)).dx;
    final loopDistance =
        tester.getTopLeft(labels.at(1)).dx - tester.getTopLeft(labels.at(0)).dx;
    expect(loopDistance, greaterThan(32));
    expect(translationX(tester), 0);

    await tester.pump(const Duration(milliseconds: 999));
    expect(translationX(tester), 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(translationX(tester), closeTo(-3, 0.05));

    final periodMicros = (loopDistance / 30 * Duration.microsecondsPerSecond)
        .round();
    await tester.pump(Duration(microseconds: periodMicros - 101000));
    expect(tester.getTopLeft(labels.at(1)).dx, closeTo(viewportLeft, 0.1));

    await tester.pump(const Duration(milliseconds: 2));
    expect(tester.getTopLeft(labels.at(0)).dx, closeTo(viewportLeft, 0.1));
  });

  testWidgets('disabled animations show one ellipsized label', (tester) async {
    await tester.pumpWidget(
      host(
        const CLMarqueeText('A deliberately long device name'),
        disableAnimations: true,
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final label = tester.widget<Text>(
      find.text('A deliberately long device name'),
    );
    expect(label.overflow, TextOverflow.ellipsis);
    expect(
      find.descendant(
        of: find.byType(CLMarqueeText),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('leaving the viewport pauses and returning resumes', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: SingleChildScrollView(
              controller: scrollController,
              child: const Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: CLMarqueeText(
                      'A deliberately long device name',
                      startDelay: Duration.zero,
                    ),
                  ),
                  SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    final beforeLeaving = translationX(tester);
    expect(beforeLeaving, lessThan(0));

    scrollController.jumpTo(100);
    await tester.pump();
    final whileHidden = translationX(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(translationX(tester), closeTo(whileHidden, 0.001));

    scrollController.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(translationX(tester), lessThan(whileHidden));
  });
}
