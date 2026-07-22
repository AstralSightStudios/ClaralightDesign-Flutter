import 'dart:ui' as ui;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _barKey = Key('progress-bar');
const _boundaryKey = Key('progress-boundary');
const _sweepColor = Color(0xFFFF0000);

Widget _host(
  Widget child, {
  bool disableAnimations = false,
  bool tickerEnabled = true,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: TickerMode(
        enabled: tickerEnabled,
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

Widget _bar(double? value) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: SizedBox(
      width: 120,
      child: CLProgressBar(
        key: _barKey,
        value: value,
        color: _sweepColor,
        height: 10,
      ),
    ),
  );
}

Future<List<int>> _accentWeights(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final y = image.height ~/ 2;
    final weights = List<int>.generate(image.width, (x) {
      final offset = (y * image.width + x) * 4;
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      return red - (green > blue ? green : blue);
    });
    image.dispose();
    return weights;
  }))!;
}

Future<double> _sweepCenter(WidgetTester tester) async {
  final weights = await _accentWeights(tester);
  var weightedX = 0.0;
  var totalWeight = 0;
  for (var x = 0; x < weights.length; x++) {
    final weight = weights[x].clamp(0, 255);
    weightedX += (x + 0.5) * weight;
    totalWeight += weight;
  }
  expect(totalWeight, greaterThan(0), reason: 'The accent must be visible');
  return weightedX / totalWeight;
}

Future<(double, double)> _sweepBounds(WidgetTester tester) async {
  final weights = await _accentWeights(tester);
  final left = weights.indexWhere((weight) => weight > 3);
  final right = weights.lastIndexWhere((weight) => weight > 3);
  expect(left, greaterThanOrEqualTo(0), reason: 'The accent must be visible');
  return (left.toDouble(), right + 1.0);
}

Future<void> _startSweep(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 520));
}

void _expectPhasePreserved(double before, double after) {
  expect(after, closeTo(before, 1.5));
}

void _expectLinearStep(double before, double after) {
  expect(after - before, closeTo(15.84, 1.5));
}

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

  testWidgets('indeterminate sweep travels linearly at equal intervals', (
    tester,
  ) async {
    await _startSweep(tester, _host(_bar(null)));

    final first = await _sweepCenter(tester);
    await tester.pump(const Duration(milliseconds: 130));
    final second = await _sweepCenter(tester);
    await tester.pump(const Duration(milliseconds: 130));
    final third = await _sweepCenter(tester);

    _expectLinearStep(first, second);
    _expectLinearStep(second, third);
  });

  testWidgets('reduced motion shows a centered static sweep without frames', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bar(null), disableAnimations: true));
    await tester.pump();

    final center = await _sweepCenter(tester);
    final (left, right) = await _sweepBounds(tester);
    expect(center, closeTo(60, 1.5));
    expect(left, closeTo(40.8, 1.5));
    expect(right, closeTo(79.2, 1.5));

    await tester.pump(const Duration(seconds: 2));
    expect(await _sweepCenter(tester), closeTo(center, 0.01));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion preserves the moving sweep phase', (
    tester,
  ) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    Widget buildHost() => ValueListenableBuilder<bool>(
      valueListenable: reduced,
      builder: (context, value, child) =>
          _host(_bar(null), disableAnimations: value),
    );

    await _startSweep(tester, buildHost());
    final before = await _sweepCenter(tester);

    reduced.value = true;
    await tester.pump();
    expect(await _sweepCenter(tester), closeTo(60, 1.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await _sweepCenter(tester), closeTo(60, 1.5));

    reduced.value = false;
    await tester.pump();
    final resumed = await _sweepCenter(tester);
    _expectPhasePreserved(before, resumed);
    await tester.pump(const Duration(milliseconds: 130));
    _expectLinearStep(resumed, await _sweepCenter(tester));
  });

  testWidgets('disabled TickerMode preserves and resumes the sweep phase', (
    tester,
  ) async {
    final tickerEnabled = ValueNotifier(true);
    addTearDown(tickerEnabled.dispose);
    Widget buildHost() => ValueListenableBuilder<bool>(
      valueListenable: tickerEnabled,
      builder: (context, value, child) =>
          _host(_bar(null), tickerEnabled: value),
    );

    await _startSweep(tester, buildHost());
    final before = await _sweepCenter(tester);

    tickerEnabled.value = false;
    await tester.pump();
    final gated = await _sweepCenter(tester);
    await tester.pump(const Duration(milliseconds: 400));
    _expectPhasePreserved(gated, await _sweepCenter(tester));

    tickerEnabled.value = true;
    await tester.pump();
    final resumed = await _sweepCenter(tester);
    _expectPhasePreserved(before, resumed);
    await tester.pump(const Duration(milliseconds: 130));
    _expectLinearStep(resumed, await _sweepCenter(tester));
  });

  testWidgets('paused lifecycle preserves and resumes the sweep phase', (
    tester,
  ) async {
    await _startSweep(tester, _host(_bar(null)));
    final before = await _sweepCenter(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final gated = await _sweepCenter(tester);
    await tester.pump(const Duration(milliseconds: 400));
    _expectPhasePreserved(gated, await _sweepCenter(tester));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final resumed = await _sweepCenter(tester);
    _expectPhasePreserved(before, resumed);
    await tester.pump(const Duration(milliseconds: 130));
    _expectLinearStep(resumed, await _sweepCenter(tester));
  });

  testWidgets('leaving the viewport preserves and resumes the sweep phase', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final scrollHost = MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 40,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(children: [_bar(null), const SizedBox(height: 400)]),
          ),
        ),
      ),
    );

    await _startSweep(tester, scrollHost);
    final before = await _sweepCenter(tester);

    scrollController.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    scrollController.jumpTo(0);
    await tester.pump();
    await tester.pump();
    final resumed = await _sweepCenter(tester);
    _expectPhasePreserved(before, resumed);
    await tester.pump(const Duration(milliseconds: 130));
    _expectLinearStep(resumed, await _sweepCenter(tester));
  });

  testWidgets('determinate to indeterminate waits for visibility report', (
    tester,
  ) async {
    final controller = VisibilityDetectorController.instance;
    controller.updateInterval = const Duration(days: 1);
    final value = ValueNotifier<double?>(0.4);
    addTearDown(value.dispose);

    try {
      await tester.pumpWidget(
        ValueListenableBuilder<double?>(
          valueListenable: value,
          builder: (context, progress, child) => _host(_bar(progress)),
        ),
      );
      value.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        (await _accentWeights(tester)).where((weight) => weight > 3),
        isEmpty,
      );

      controller.notifyNow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(
        (await _accentWeights(tester)).where((weight) => weight > 3),
        isNotEmpty,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.updateInterval = Duration.zero;
      controller.notifyNow();
    }
  });

  testWidgets('progress semantics are unchanged in normal and reduced motion', (
    tester,
  ) async {
    for (final disableAnimations in [false, true]) {
      await tester.pumpWidget(
        _host(_bar(null), disableAnimations: disableAnimations),
      );
      await tester.pump();
      final semantics = tester.getSemantics(
        find.descendant(
          of: find.byType(CLProgressBar),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.value, isEmpty);

      await tester.pumpWidget(
        _host(_bar(0.42), disableAnimations: disableAnimations),
      );
      expect(
        tester
            .getSemantics(
              find.descendant(
                of: find.byType(CLProgressBar),
                matching: find.byType(Semantics),
              ),
            )
            .value,
        '42%',
      );
    }
  });

  testWidgets('determinate progress timing contracts remain unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            SizedBox(width: 120, child: CLProgressBar(value: 0.4)),
            CLProgressRing(value: 0.4),
          ],
        ),
      ),
    );

    final barAnimation = tester.widget<AnimatedFractionallySizedBox>(
      find.descendant(
        of: find.byType(CLProgressBar),
        matching: find.byType(AnimatedFractionallySizedBox),
      ),
    );
    expect(barAnimation.duration, const Duration(milliseconds: 380));
    expect(barAnimation.curve, Curves.easeOutCubic);
    expect(barAnimation.widthFactor, 0.4);

    final ringAnimation = tester.widget<TweenAnimationBuilder<double>>(
      find.descendant(
        of: find.byType(CLProgressRing),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
    );
    expect(ringAnimation.duration, const Duration(milliseconds: 380));
    expect(ringAnimation.curve, Curves.easeOutCubic);
  });
}
