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
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: textDirection,
        child: TickerMode(
          enabled: tickerEnabled,
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
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

Future<List<List<int>>> _accentRaster(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final weights = List<List<int>>.generate(image.height, (y) {
      return List<int>.generate(image.width, (x) {
        final offset = (y * image.width + x) * 4;
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        final blue = bytes.getUint8(offset + 2);
        return red - (green > blue ? green : blue);
      });
    });
    image.dispose();
    return weights;
  }))!;
}

Future<List<int>> _accentWeights(WidgetTester tester) async {
  final raster = await _accentRaster(tester);
  return raster[raster.length ~/ 2];
}

Future<(double, double)?> _accentBounds(WidgetTester tester) async {
  final weights = await _accentWeights(tester);
  final left = weights.indexWhere((weight) => weight > 3);
  if (left < 0) return null;
  final right = weights.lastIndexWhere((weight) => weight > 3);
  return (left.toDouble(), right + 1.0);
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
  final bounds = await _accentBounds(tester);
  expect(bounds, isNotNull, reason: 'The accent must be visible');
  return bounds!;
}

Future<(double, double)> _contiguousAccentBounds(WidgetTester tester) async {
  final weights = await _accentWeights(tester);
  final left = weights.indexWhere((weight) => weight > 3);
  final right = weights.lastIndexWhere((weight) => weight > 3);
  expect(left, greaterThanOrEqualTo(0), reason: 'The accent must be visible');
  expect(
    weights.sublist(left, right + 1).every((weight) => weight > 3),
    isTrue,
    reason: 'The determinate fill must be one continuous shape',
  );
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

  testWidgets('determinate retargets from its painted edge', (tester) async {
    final value = ValueNotifier(0.1);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: value,
        builder: (context, progress, child) => _host(_bar(progress)),
      ),
    );

    final initial = await _sweepBounds(tester);
    expect(initial, (0.0, 12.0));

    value.value = 1;
    await tester.pump();
    expect(await _sweepBounds(tester), initial);
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byType(CLProgressBar),
              matching: find.byType(Semantics),
            ),
          )
          .value,
      '100%',
    );

    await tester.pump(const Duration(milliseconds: 80));
    final beforeRetarget = await _sweepBounds(tester);
    expect(beforeRetarget.$2, allOf(greaterThan(12), lessThan(120)));

    value.value = 0.2;
    await tester.pump();
    final afterRetarget = await _sweepBounds(tester);
    expect(afterRetarget.$2, closeTo(beforeRetarget.$2, 0.01));
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byType(CLProgressBar),
              matching: find.byType(Semantics),
            ),
          )
          .value,
      '20%',
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect((await _sweepBounds(tester)).$2, closeTo(24, 1));
  });

  testWidgets('rapid determinate retargets preserve one continuous fill', (
    tester,
  ) async {
    final value = ValueNotifier(0.1);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: value,
        builder: (context, progress, child) => _host(_bar(progress)),
      ),
    );

    final initial = await _contiguousAccentBounds(tester);
    expect(initial, (0.0, 12.0));

    value.value = 0.9;
    await tester.pump();
    expect(await _contiguousAccentBounds(tester), initial);
    await tester.pump(const Duration(milliseconds: 40));
    final towardNinety = await _contiguousAccentBounds(tester);
    expect(towardNinety.$2, greaterThan(initial.$2));

    value.value = 0.2;
    await tester.pump();
    expect(
      (await _contiguousAccentBounds(tester)).$2,
      closeTo(towardNinety.$2, 0.01),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final towardTwenty = await _contiguousAccentBounds(tester);
    expect(towardTwenty.$2, lessThan(towardNinety.$2));

    value.value = 0.75;
    await tester.pump();
    expect(
      (await _contiguousAccentBounds(tester)).$2,
      closeTo(towardTwenty.$2, 0.01),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(await _contiguousAccentBounds(tester), (0.0, 90.0));
  });

  testWidgets('reduced motion snaps targets and leaves no scheduled frames', (
    tester,
  ) async {
    final value = ValueNotifier(0.2);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: value,
        builder: (context, progress, child) =>
            _host(_bar(progress), disableAnimations: true),
      ),
    );
    await tester.pump();
    expect(await _sweepBounds(tester), (0.0, 24.0));

    value.value = 0.8;
    await tester.pump();
    expect(await _sweepBounds(tester), (0.0, 96.0));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    expect(await _sweepBounds(tester), (0.0, 96.0));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('enabling reduced motion snaps an in-flight target', (
    tester,
  ) async {
    final value = ValueNotifier(0.2);
    final reduced = ValueNotifier(false);
    addTearDown(value.dispose);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: reduced,
        builder: (context, animationsDisabled, child) {
          return ValueListenableBuilder<double>(
            valueListenable: value,
            builder: (context, progress, child) =>
                _host(_bar(progress), disableAnimations: animationsDisabled),
          );
        },
      ),
    );

    value.value = 0.8;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final inFlight = (await _sweepBounds(tester)).$2;
    expect(inFlight, allOf(greaterThan(24), lessThan(96)));

    reduced.value = true;
    await tester.pump();
    expect(await _sweepBounds(tester), (0.0, 96.0));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    expect(await _sweepBounds(tester), (0.0, 96.0));
  });

  testWidgets('determinate boundaries preserve rounded clipping', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bar(0), disableAnimations: true));
    await tester.pump();
    expect(await _accentBounds(tester), isNull);

    await tester.pumpWidget(_host(_bar(1), disableAnimations: true));
    await tester.pump();
    expect(await _sweepBounds(tester), (0.0, 120.0));
    final fullRaster = await _accentRaster(tester);
    expect(fullRaster[0][0], lessThanOrEqualTo(3));
    expect(fullRaster[0][60], greaterThan(100));
    expect(fullRaster[5][0], greaterThan(100));
    expect(fullRaster[9][119], lessThanOrEqualTo(3));

    await tester.pumpWidget(_host(_bar(0.5), disableAnimations: true));
    await tester.pump();
    expect(await _sweepBounds(tester), (0.0, 60.0));
    final halfRaster = await _accentRaster(tester);
    expect(halfRaster[0][50], greaterThan(100));
    expect(halfRaster[0][59], lessThanOrEqualTo(3));
    expect(halfRaster[5][59], greaterThan(100));
  });

  testWidgets('determinate progress grows from the right in RTL', (
    tester,
  ) async {
    final value = ValueNotifier(0.25);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: value,
        builder: (context, progress, child) =>
            _host(_bar(progress), textDirection: TextDirection.rtl),
      ),
    );

    expect(await _contiguousAccentBounds(tester), (90.0, 120.0));
    value.value = 0.75;
    await tester.pump();
    expect(await _contiguousAccentBounds(tester), (90.0, 120.0));

    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = await _contiguousAccentBounds(tester);
    expect(intermediate.$1, allOf(greaterThan(30), lessThan(90)));
    expect(intermediate.$2, 120);

    await tester.pump(const Duration(milliseconds: 100));
    expect(await _contiguousAccentBounds(tester), (30.0, 120.0));
  });

  testWidgets('determinate progress animates paint in fixed track bounds', (
    tester,
  ) async {
    final value = ValueNotifier(0.1);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      _host(
        ValueListenableBuilder<double>(
          valueListenable: value,
          builder: (context, progress, child) => _bar(progress),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(CLProgressBar),
        matching: find.byType(AnimatedFractionallySizedBox),
      ),
      findsNothing,
    );
    final paintFinder = find.descendant(
      of: find.byType(CLProgressBar),
      matching: find.byType(CustomPaint),
    );
    expect(paintFinder, findsOneWidget);

    final paintRect = tester.getRect(paintFinder);
    expect(paintRect.size, const Size(120, 10));
    expect(paintRect, tester.getRect(find.byType(CLProgressBar)));

    final animation = tester.widget<TweenAnimationBuilder<double>>(
      find.descendant(
        of: find.byType(CLProgressBar),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
    );
    expect(animation.duration, const Duration(milliseconds: 200));
    expect(animation.curve, const Cubic(0.23, 1, 0.32, 1));

    value.value = 1;
    await tester.pump();
    expect(tester.getRect(paintFinder), paintRect);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(paintFinder), paintRect);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(paintFinder), paintRect);
  });

  testWidgets('progress ring timing contract remains unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const CLProgressRing(value: 0.4)));

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
