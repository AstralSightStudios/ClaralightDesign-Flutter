import 'dart:ui' as ui;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui/src/scrolling/edge_effects.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Color>> _readPixels(
  WidgetTester tester,
  Finder boundary,
  List<Offset> points,
) async {
  return (await tester.runAsync(() async {
    final renderObject = tester.renderObject<RenderRepaintBoundary>(boundary);
    final image = await renderObject.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final colors = points.map((point) {
      final byteOffset =
          (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
      return Color.fromARGB(
        bytes.getUint8(byteOffset + 3),
        bytes.getUint8(byteOffset),
        bytes.getUint8(byteOffset + 1),
        bytes.getUint8(byteOffset + 2),
      );
    }).toList();
    image.dispose();
    return colors;
  }))!;
}

const _autoScrollbarViewportKey = Key('auto-scrollbar-timing-viewport');

Widget _buildAutoScrollbarHarness({
  required ScrollController controller,
  bool disableAnimations = false,
}) {
  final colors = const CLColorScheme.dark().copyWith(selection: Colors.white);
  return MaterialApp(
    home: CLTheme(
      data: CLThemeData(colors: colors),
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(
          child: SizedBox(
            key: _autoScrollbarViewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.vertical,
              blurExtent: EdgeInsets.zero,
              blurSigma: EdgeInsets.zero,
              horizontalScrollbar: CLScrollbarVisibility.hidden,
              verticalScrollbar: CLScrollbarVisibility.auto,
              verticalController: controller,
              child: const SizedBox(height: 200),
            ),
          ),
        ),
      ),
    ),
  );
}

RawScrollbar _autoScrollbar(WidgetTester tester) {
  return tester.widget<RawScrollbar>(
    find.byKey(const ValueKey<Axis>(Axis.vertical)),
  );
}

double _autoScrollbarAlpha(WidgetTester tester) {
  return _autoScrollbar(tester).thumbColor!.a;
}

void _expectAutoScrollbarAlpha(WidgetTester tester, double expected) {
  expect(_autoScrollbarAlpha(tester), closeTo(expected, 1e-3 + 1 / 255));
}

Future<void> _revealAutoScrollbar(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(_autoScrollbarViewportKey)),
  );
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 160));
  _expectAutoScrollbarAlpha(tester, 1);
  await gesture.up();
  await tester.pump();
}

void main() {
  test('CLScrollable has stable public defaults', () {
    const scrollable = CLScrollable(child: SizedBox());

    expect(scrollable.direction, CLScrollDirection.both);
    expect(scrollable.blurExtent, const EdgeInsets.all(24));
    expect(scrollable.blurSigma, const EdgeInsets.all(5));
    expect(scrollable.padding, EdgeInsets.zero);
    expect(scrollable.scrollbarPadding, EdgeInsets.zero);
    expect(scrollable.horizontalScrollbar, CLScrollbarVisibility.auto);
    expect(scrollable.verticalScrollbar, CLScrollbarVisibility.auto);
    expect(scrollable.horizontalController, isNull);
    expect(scrollable.verticalController, isNull);
    expect(scrollable.borderRadius, BorderRadius.zero);
  });

  testWidgets('CLScrollable can precache its visual effect', (tester) async {
    await CLScrollable.precache();
  });

  test('CLScrollable requires a controller per axis', () {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    expect(
      () => CLScrollable(
        horizontalController: controller,
        verticalController: controller,
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('controller updates detach external controllers safely', (
    tester,
  ) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget build(ScrollController? controller) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              key: const Key('scrollable'),
              direction: CLScrollDirection.horizontal,
              blurExtent: EdgeInsets.zero,
              blurSigma: EdgeInsets.zero,
              horizontalScrollbar: CLScrollbarVisibility.hidden,
              verticalScrollbar: CLScrollbarVisibility.hidden,
              horizontalController: controller,
              child: const SizedBox(width: 200, height: 40),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(first));
    expect(first.hasClients, isTrue);

    await tester.pumpWidget(build(second));
    expect(first.hasClients, isFalse);
    expect(second.hasClients, isTrue);

    await tester.pumpWidget(build(null));
    expect(second.hasClients, isFalse);
  });

  testWidgets('CLScrollable rejects a negative blur extent', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLScrollable(
          blurExtent: EdgeInsets.only(top: -1),
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('CLScrollable rejects a negative blur sigma', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLScrollable(
          blurSigma: EdgeInsets.only(left: -1),
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('CLScrollable rejects an infinite blur extent', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLScrollable(
          blurExtent: EdgeInsets.only(bottom: double.infinity),
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('CLScrollable rejects an infinite blur sigma', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLScrollable(
          blurSigma: EdgeInsets.only(right: double.infinity),
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('both direction requires bounded width and height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 100,
            child: CLScrollable(child: SizedBox(width: 200, height: 200)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('both direction exposes two independent scroll extents', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');
    const contentKey = Key('content');

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(key: contentKey, width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    expect(horizontal.hasClients, isTrue);
    expect(vertical.hasClients, isTrue);
    expect(horizontal.position.maxScrollExtent, 140);
    expect(vertical.position.maxScrollExtent, 120);
    expect(tester.getSize(find.byKey(viewportKey)), const Size(100, 80));
    expect(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getTopLeft(find.byKey(viewportKey)),
    );
  });

  testWidgets('padding scrolls with the child and contributes to extent', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');
    const contentKey = Key('content');

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              padding: const EdgeInsets.fromLTRB(10, 20, 30, 40),
              child: const SizedBox(key: contentKey, width: 200, height: 150),
            ),
          ),
        ),
      ),
    );

    expect(horizontal.position.maxScrollExtent, 140);
    expect(vertical.position.maxScrollExtent, 130);
    expect(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getTopLeft(find.byKey(viewportKey)) + const Offset(10, 20),
    );

    horizontal.jumpTo(10);
    vertical.jumpTo(20);
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getTopLeft(find.byKey(viewportKey)),
    );
  });

  testWidgets('scrollbar padding constrains both tracks only', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const scrollbarPadding = EdgeInsets.fromLTRB(10, 20, 30, 40);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              scrollbarPadding: scrollbarPadding,
              horizontalScrollbar: CLScrollbarVisibility.always,
              verticalScrollbar: CLScrollbarVisibility.always,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    final scrollbars = tester.widgetList<RawScrollbar>(
      find.byType(RawScrollbar),
    );
    expect(scrollbars, hasLength(2));
    expect(
      scrollbars.every((scrollbar) => scrollbar.padding == scrollbarPadding),
      isTrue,
    );
    expect(
      scrollbars.every(
        (scrollbar) =>
            scrollbar.radius == null &&
            scrollbar.shape is RoundedSuperellipseBorder,
      ),
      isTrue,
    );
    expect(horizontal.position.maxScrollExtent, 140);
    expect(vertical.position.maxScrollExtent, 120);
  });

  testWidgets('CLScrollable rejects negative scrollbar padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLScrollable(
          scrollbarPadding: EdgeInsets.only(right: -1),
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('vertical direction disables horizontal scrolling', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.vertical,
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    expect(horizontal.position.maxScrollExtent, 0);
    expect(vertical.position.maxScrollExtent, 120);
  });

  testWidgets('a touch drag does not overscroll a locked axis', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('locked-axis-viewport');

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(),
        ),
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.vertical,
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(viewportKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();

    expect(horizontal.offset, 0);
    expect(vertical.offset, 0);

    await gesture.up();
  });

  testWidgets('a touch drag does not overscroll non-scrollable content', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('non-scrollable-viewport');

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(),
        ),
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 100, height: 200),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(viewportKey)),
    );
    await gesture.moveBy(const Offset(30, -30));
    await tester.pump();

    expect(horizontal.offset, 0);
    expect(vertical.offset, greaterThan(0));

    await gesture.up();
  });

  testWidgets('scrollable content keeps platform overscroll physics', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    const viewportKey = Key('scrollable-bounce-viewport');

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(),
        ),
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.horizontal,
              horizontalController: horizontal,
              child: const SizedBox(width: 200, height: 80),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(viewportKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();

    expect(horizontal.offset, lessThan(0));

    await gesture.up();
  });

  testWidgets('horizontal direction starts from the right in RTL', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    const viewportKey = Key('viewport');
    const contentKey = Key('content');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.horizontal,
              horizontalController: horizontal,
              child: const SizedBox(key: contentKey, width: 240, height: 50),
            ),
          ),
        ),
      ),
    );

    expect(horizontal.position.maxScrollExtent, 140);
    expect(
      tester.getTopRight(find.byKey(contentKey)),
      tester.getTopRight(find.byKey(viewportKey)),
    );

    horizontal.jumpTo(140);
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(contentKey)),
      tester.getTopLeft(find.byKey(viewportKey)),
    );
  });

  testWidgets('a diagonal touch drag scrolls both axes', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(viewportKey)),
    );
    await gesture.moveBy(const Offset(-40, -30));
    await tester.pump();

    expect(horizontal.offset, greaterThan(0));
    expect(vertical.offset, greaterThan(0));

    await gesture.up();
  });

  testWidgets('a mouse drag does not scroll either axis', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(viewportKey)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-40, -30));
    await tester.pump();

    expect(horizontal.offset, 0);
    expect(vertical.offset, 0);

    await gesture.up();
  });

  testWidgets('a diagonal pointer signal scrolls both axes', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(viewportKey)),
        scrollDelta: const Offset(20, 30),
      ),
    );
    await tester.pump();

    expect(horizontal.offset, 20);
    expect(vertical.offset, 30);
  });

  testWidgets('Shift maps a mouse wheel to the horizontal axis', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(find.byKey(viewportKey)),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(horizontal.offset, 30);
    expect(vertical.offset, 0);
  });

  testWidgets('a pointer signal passes to an ancestor at the edge', (
    tester,
  ) async {
    final parent = ScrollController();
    final vertical = ScrollController();
    addTearDown(parent.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            height: 100,
            child: SingleChildScrollView(
              controller: parent,
              child: Column(
                children: [
                  SizedBox(
                    key: viewportKey,
                    width: 100,
                    height: 80,
                    child: CLScrollable(
                      direction: CLScrollDirection.vertical,
                      verticalController: vertical,
                      child: const SizedBox(height: 200),
                    ),
                  ),
                  const SizedBox(height: 200),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    vertical.jumpTo(vertical.position.maxScrollExtent);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(viewportKey)),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await tester.pump();

    expect(vertical.offset, vertical.position.maxScrollExtent);
    expect(parent.offset, 30);
  });

  testWidgets('ensureVisible reveals a child on both axes', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const targetKey = Key('target');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(
                width: 240,
                height: 200,
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SizedBox(key: targetKey, width: 20, height: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await Scrollable.ensureVisible(
      tester.element(find.byKey(targetKey)),
      duration: Duration.zero,
    );
    await tester.pump();

    expect(horizontal.offset, 140);
    expect(vertical.offset, 120);
  });

  testWidgets('semantics expose scrolling in both axes', (tester) async {
    final semantics = tester.ensureSemantics();
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const scrollableKey = Key('scrollable');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              key: scrollableKey,
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 240, height: 200),
            ),
          ),
        ),
      ),
    );
    horizontal.jumpTo(50);
    vertical.jumpTo(50);
    await tester.pump();

    final horizontalSemantics = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.hasAction(SemanticsAction.scrollLeft) &&
          data.hasAction(SemanticsAction.scrollRight);
    });
    final verticalSemantics = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.hasAction(SemanticsAction.scrollUp) &&
          data.hasAction(SemanticsAction.scrollDown);
    });
    expect(horizontalSemantics, findsOne);
    expect(verticalSemantics, findsOne);
    semantics.dispose();
  });

  testWidgets('a horizontal semantics action scrolls the viewport', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.horizontal,
              horizontalController: horizontal,
              child: const SizedBox(width: 240, height: 50),
            ),
          ),
        ),
      ),
    );

    final node = find.semantics.byAction(SemanticsAction.scrollLeft);
    expect(node, findsOne);
    tester.semantics.performAction(node, SemanticsAction.scrollLeft);
    await tester.pump();

    expect(horizontal.offset, 80);
    semantics.dispose();
  });

  testWidgets('an active edge masks content even when sigma is zero', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    const boundaryKey = Key('boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.blue,
              child: SizedBox(
                width: 100,
                height: 40,
                child: CLScrollable(
                  direction: CLScrollDirection.horizontal,
                  blurExtent: const EdgeInsets.symmetric(horizontal: 20),
                  blurSigma: EdgeInsets.zero,
                  horizontalScrollbar: CLScrollbarVisibility.hidden,
                  verticalScrollbar: CLScrollbarVisibility.hidden,
                  horizontalController: horizontal,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox(width: 200, height: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(50, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].r, greaterThan(pixels[0].b));
    expect(pixels[1].r, greaterThan(pixels[1].b));
    expect(pixels[2].b, greaterThan(pixels[2].r));

    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pumpAndSettle();

    pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(50, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].b, greaterThan(pixels[0].r));
    expect(pixels[1].r, greaterThan(pixels[1].b));
    expect(pixels[2].r, greaterThan(pixels[2].b));
  });

  testWidgets('edge transitions complete in 160 milliseconds', (tester) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    const boundaryKey = Key('animated-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.blue,
              child: SizedBox(
                width: 100,
                height: 40,
                child: CLScrollable(
                  direction: CLScrollDirection.horizontal,
                  blurExtent: const EdgeInsets.symmetric(horizontal: 20),
                  blurSigma: EdgeInsets.zero,
                  horizontalScrollbar: CLScrollbarVisibility.hidden,
                  verticalScrollbar: CLScrollbarVisibility.hidden,
                  horizontalController: horizontal,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox(width: 200, height: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();
    var pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].r, greaterThan(pixels[0].b));
    expect(pixels[1].b, greaterThan(pixels[1].r));

    await tester.pump(const Duration(milliseconds: 80));
    pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].b, greaterThan(pixels[0].r));
    expect(pixels[1].b, greaterThan(pixels[1].r));

    await tester.pump(const Duration(milliseconds: 80));
    pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].b, greaterThan(pixels[0].r));
    expect(pixels[1].r, greaterThan(pixels[1].b));
  });

  testWidgets('disabled animations switch active edges immediately', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    const boundaryKey = Key('reduced-motion-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.blue,
                child: SizedBox(
                  width: 100,
                  height: 40,
                  child: CLScrollable(
                    direction: CLScrollDirection.horizontal,
                    blurExtent: const EdgeInsets.symmetric(horizontal: 20),
                    blurSigma: EdgeInsets.zero,
                    horizontalScrollbar: CLScrollbarVisibility.hidden,
                    verticalScrollbar: CLScrollbarVisibility.hidden,
                    horizontalController: horizontal,
                    child: const ColoredBox(
                      color: Colors.red,
                      child: SizedBox(width: 200, height: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();

    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 20),
      Offset(99, 20),
    ]);
    expect(pixels[0].b, greaterThan(pixels[0].r));
    expect(pixels[1].r, greaterThan(pixels[1].b));
  });

  testWidgets('borderRadius clips the viewport content', (tester) async {
    const boundaryKey = Key('rounded-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.blue,
              child: SizedBox(
                width: 100,
                height: 40,
                child: CLScrollable(
                  blurExtent: EdgeInsets.zero,
                  blurSigma: EdgeInsets.zero,
                  horizontalScrollbar: CLScrollbarVisibility.hidden,
                  verticalScrollbar: CLScrollbarVisibility.hidden,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox(width: 100, height: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CLSmoothClip), findsOneWidget);

    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(0, 0),
      Offset(12, 12),
      Offset(50, 20),
    ]);
    expect(pixels[0].b, greaterThan(pixels[0].r));
    expect(pixels[1].r, greaterThan(pixels[1].b));
    expect(pixels[2].r, greaterThan(pixels[2].b));
  });

  testWidgets('overlapping edge masks use the minimum alpha', (tester) async {
    const boundaryKey = Key('corner-mask-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 100,
              height: 40,
              child: CLScrollable(
                blurExtent: const EdgeInsets.only(right: 20, bottom: 20),
                blurSigma: EdgeInsets.zero,
                horizontalScrollbar: CLScrollbarVisibility.hidden,
                verticalScrollbar: CLScrollbarVisibility.hidden,
                child: const ColoredBox(
                  color: Colors.white,
                  child: SizedBox(width: 200, height: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(90, 30),
    ]);
    expect(pixels.single.a, inInclusiveRange(0.6, 0.72));
  });

  testWidgets('an active edge progressively blurs nearby content', (
    tester,
  ) async {
    await CLScrollable.precache();
    const boundaryKey = Key('blur-boundary');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                width: 100,
                height: 40,
                child: CLScrollable(
                  direction: CLScrollDirection.horizontal,
                  blurExtent: const EdgeInsets.only(right: 20),
                  blurSigma: const EdgeInsets.only(right: 8),
                  horizontalScrollbar: CLScrollbarVisibility.hidden,
                  verticalScrollbar: CLScrollbarVisibility.hidden,
                  child: const Row(
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: SizedBox(width: 90, height: 40),
                      ),
                      ColoredBox(
                        color: Colors.white,
                        child: SizedBox(width: 110, height: 40),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(70, 20),
      Offset(88, 20),
    ]);
    expect(pixels[0].r, lessThan(0.02));
    expect(pixels[1].r, greaterThan(0.005));
  });

  testWidgets('removing an active blur disposes its textures safely', (
    tester,
  ) async {
    await CLScrollable.precache();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 40,
            child: CLScrollable(
              direction: CLScrollDirection.horizontal,
              blurExtent: const EdgeInsets.only(right: 20),
              blurSigma: const EdgeInsets.only(right: 8),
              horizontalScrollbar: CLScrollbarVisibility.hidden,
              verticalScrollbar: CLScrollbarVisibility.hidden,
              child: const SizedBox(width: 200, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('edge atlas cache reuses geometry across activation and resize', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);

    Widget build(double width) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 80,
            child: CLScrollable(
              direction: CLScrollDirection.horizontal,
              horizontalController: horizontal,
              blurExtent: const EdgeInsets.symmetric(horizontal: 20),
              blurSigma: const EdgeInsets.symmetric(horizontal: 5),
              horizontalScrollbar: CLScrollbarVisibility.hidden,
              verticalScrollbar: CLScrollbarVisibility.hidden,
              child: const SizedBox(width: 300, height: 80),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(100));
    await tester.pumpAndSettle();
    final state = tester.state<CLEdgeEffectsState>(find.byType(CLEdgeEffects));
    final initialBuilds = state.atlasBuildCount;
    expect(initialBuilds, greaterThanOrEqualTo(1));

    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 80));
    horizontal.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(state.atlasBuildCount, initialBuilds);

    await tester.pumpWidget(build(120));
    await tester.pumpAndSettle();
    expect(state.atlasBuildCount, initialBuilds + 1);

    await tester.pumpWidget(build(100));
    await tester.pumpAndSettle();
    expect(state.atlasBuildCount, initialBuilds + 1);
    expect(state.atlasHitCount, greaterThan(0));

    await tester.pumpWidget(build(120));
    await tester.pumpAndSettle();
    expect(state.atlasBuildCount, initialBuilds + 1);

    await tester.pumpWidget(build(140));
    await tester.pumpAndSettle();
    expect(state.atlasBuildCount, initialBuilds + 2);

    // The third geometry evicts exactly the least-recently-used entry.
    await tester.pumpWidget(build(100));
    await tester.pumpAndSettle();
    expect(state.atlasBuildCount, initialBuilds + 3);
  });

  testWidgets('always paints themed scrollbars on the right and bottom', (
    tester,
  ) async {
    const boundaryKey = Key('scrollbar-boundary');
    final colors = const CLColorScheme.dark().copyWith(selection: Colors.green);

    await tester.pumpWidget(
      MaterialApp(
        home: CLTheme(
          data: CLThemeData(colors: colors),
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: CLScrollable(
                    blurExtent: EdgeInsets.zero,
                    blurSigma: EdgeInsets.zero,
                    horizontalScrollbar: CLScrollbarVisibility.always,
                    verticalScrollbar: CLScrollbarVisibility.always,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: SizedBox(width: 200, height: 200),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(98, 10),
      Offset(10, 78),
      Offset(95, 10),
      Offset(98, 0),
      Offset(98, 48),
      Offset(98, 60),
      Offset(60, 60),
    ]);
    expect(pixels[0].g, greaterThan(pixels[0].r));
    expect(pixels[1].g, greaterThan(pixels[1].r));
    expect(pixels[2].g, lessThan(0.02));
    expect(pixels[3].g, lessThan(0.02));
    expect(pixels[4].g, greaterThan(pixels[4].r));
    expect(pixels[5].g, lessThan(0.02));
    expect(pixels[6].g, lessThan(0.02));
  });

  testWidgets('hidden scrollbars stay absent during hover and scrolling', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const boundaryKey = Key('hidden-scrollbar-boundary');
    final colors = const CLColorScheme.dark().copyWith(selection: Colors.green);

    await tester.pumpWidget(
      MaterialApp(
        home: CLTheme(
          data: CLThemeData(colors: colors),
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: CLScrollable(
                    blurExtent: EdgeInsets.zero,
                    blurSigma: EdgeInsets.zero,
                    horizontalScrollbar: CLScrollbarVisibility.hidden,
                    verticalScrollbar: CLScrollbarVisibility.hidden,
                    horizontalController: horizontal,
                    verticalController: vertical,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: SizedBox(width: 200, height: 200),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(boundaryKey)));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(find.byKey(boundaryKey)),
        scrollDelta: const Offset(20, 20),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(horizontal.offset, 20);
    expect(vertical.offset, 20);
    final pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(98, 10),
      Offset(20, 78),
    ]);
    expect(pixels[0].g, lessThan(0.02));
    expect(pixels[1].g, lessThan(0.02));
    await mouse.removePointer();
  });

  testWidgets('always scrollbars drag their matching axis', (tester) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('interactive-scrollbar-viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              blurExtent: EdgeInsets.zero,
              blurSigma: EdgeInsets.zero,
              horizontalScrollbar: CLScrollbarVisibility.always,
              verticalScrollbar: CLScrollbarVisibility.always,
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 300, height: 300),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final topLeft = tester.getTopLeft(find.byKey(viewportKey));

    var gesture = await tester.startGesture(
      topLeft + const Offset(98, 20),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.up();

    expect(vertical.offset, greaterThan(0));
    expect(horizontal.offset, 0);

    gesture = await tester.startGesture(
      topLeft + const Offset(20, 78),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();

    expect(horizontal.offset, greaterThan(0));
  });

  testWidgets('vertical scrollbar wins the overlapping corner hit', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    const viewportKey = Key('overlapping-scrollbar-viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            key: viewportKey,
            width: 100,
            height: 80,
            child: CLScrollable(
              blurExtent: EdgeInsets.zero,
              blurSigma: EdgeInsets.zero,
              horizontalScrollbar: CLScrollbarVisibility.always,
              verticalScrollbar: CLScrollbarVisibility.always,
              horizontalController: horizontal,
              verticalController: vertical,
              child: const SizedBox(width: 300, height: 300),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getTopLeft(find.byKey(viewportKey)) + const Offset(97, 77),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(vertical.offset, greaterThan(0));
    expect(horizontal.offset, 0);
  });

  testWidgets('auto scrollbar holds then follows the exact exit curve', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const exitCurve = Cubic(0.32, 0, 0.67, 0);

    await tester.pumpWidget(_buildAutoScrollbarHarness(controller: controller));
    await _revealAutoScrollbar(tester);

    await tester.pump(const Duration(milliseconds: 299));
    _expectAutoScrollbarAlpha(tester, 1);
    await tester.pump(const Duration(milliseconds: 1));
    _expectAutoScrollbarAlpha(tester, 1);

    for (final elapsed in [45, 90, 135]) {
      await tester.pump(const Duration(milliseconds: 45));
      _expectAutoScrollbarAlpha(tester, 1 - exitCurve.transform(elapsed / 180));
    }

    await tester.pump(const Duration(milliseconds: 44));
    expect(_autoScrollbarAlpha(tester), greaterThan(0));
    expect(_autoScrollbar(tester).interactive, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    _expectAutoScrollbarAlpha(tester, 0);
    expect(_autoScrollbar(tester).interactive, isFalse);
  });

  testWidgets('scroll activity reverses the auto scrollbar exit', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildAutoScrollbarHarness(controller: controller));
    await _revealAutoScrollbar(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 60));
    final exitAlpha = _autoScrollbarAlpha(tester);

    controller.jumpTo(controller.offset + 10);
    await tester.pump();

    _expectAutoScrollbarAlpha(tester, exitAlpha);
    expect(exitAlpha, isNot(anyOf(0, 1)));
    await tester.pump(const Duration(milliseconds: 80));
    _expectAutoScrollbarAlpha(
      tester,
      exitAlpha + (1 - exitAlpha) * Curves.easeOutCubic.transform(80 / 160),
    );
    await tester.pump(const Duration(milliseconds: 80));
    _expectAutoScrollbarAlpha(tester, 1);
  });

  testWidgets('thumb drag reverses the auto scrollbar exit', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildAutoScrollbarHarness(controller: controller));
    await _revealAutoScrollbar(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 60));
    final exitAlpha = _autoScrollbarAlpha(tester);
    final viewportTopLeft = tester.getTopLeft(
      find.byKey(_autoScrollbarViewportKey),
    );

    final drag = await tester.startGesture(
      viewportTopLeft + const Offset(98, 15),
    );
    await drag.moveBy(const Offset(0, 8));
    await tester.pump();

    expect(controller.offset, greaterThan(20));
    _expectAutoScrollbarAlpha(tester, exitAlpha);
    await tester.pump(const Duration(milliseconds: 80));
    _expectAutoScrollbarAlpha(
      tester,
      exitAlpha + (1 - exitAlpha) * Curves.easeOutCubic.transform(80 / 160),
    );
    await tester.pump(const Duration(milliseconds: 80));
    _expectAutoScrollbarAlpha(tester, 1);
    await drag.up();
  });

  testWidgets('hover reverses the auto scrollbar exit ten milliseconds early', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildAutoScrollbarHarness(controller: controller));
    await _revealAutoScrollbar(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 170));
    final exitAlpha = _autoScrollbarAlpha(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(_autoScrollbarViewportKey)));
    await tester.pump();

    _expectAutoScrollbarAlpha(tester, exitAlpha);
    expect(exitAlpha, isNot(anyOf(0, 1)));
    await tester.pump(const Duration(milliseconds: 80));
    _expectAutoScrollbarAlpha(
      tester,
      exitAlpha + (1 - exitAlpha) * Curves.easeOutCubic.transform(80 / 160),
    );
    await tester.pump(const Duration(milliseconds: 79));
    expect(_autoScrollbarAlpha(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 1));
    _expectAutoScrollbarAlpha(tester, 1);

    await mouse.removePointer();
  });

  testWidgets('disabled animations snap around the auto scrollbar hide delay', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildAutoScrollbarHarness(
        controller: controller,
        disableAnimations: true,
      ),
    );
    await tester.pump();
    _expectAutoScrollbarAlpha(tester, 0);
    expect(_autoScrollbar(tester).interactive, isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_autoScrollbarViewportKey)),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    _expectAutoScrollbarAlpha(tester, 1);
    expect(_autoScrollbar(tester).interactive, isTrue);
    await gesture.up();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 299));
    _expectAutoScrollbarAlpha(tester, 1);
    await tester.pump(const Duration(milliseconds: 1));
    _expectAutoScrollbarAlpha(tester, 0);
    expect(_autoScrollbar(tester).interactive, isFalse);
  });

  testWidgets('scroll activity reveals auto scrollbars without hover', (
    tester,
  ) async {
    const boundaryKey = Key('active-auto-scrollbar-boundary');
    final colors = const CLColorScheme.dark().copyWith(selection: Colors.green);
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CLTheme(
          data: CLThemeData(colors: colors),
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: CLScrollable(
                    blurExtent: EdgeInsets.zero,
                    blurSigma: EdgeInsets.zero,
                    horizontalScrollbar: CLScrollbarVisibility.auto,
                    verticalScrollbar: CLScrollbarVisibility.auto,
                    horizontalController: horizontal,
                    verticalController: vertical,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: SizedBox(width: 200, height: 200),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(find.byKey(boundaryKey)),
        scrollDelta: const Offset(20, 20),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(horizontal.offset, 20);
    expect(vertical.offset, 20);
    var pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(98, 10),
      Offset(20, 78),
    ]);
    expect(pixels[0].g, greaterThan(pixels[0].r));
    expect(pixels[1].g, greaterThan(pixels[1].r));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    pixels = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(98, 10),
      Offset(20, 78),
    ]);
    expect(pixels[0].g, lessThan(0.02));
    expect(pixels[1].g, lessThan(0.02));
  });

  for (final disableAnimations in [false, true]) {
    testWidgets('keyboard scroll intents are immediate '
        'with disableAnimations: $disableAnimations', (tester) async {
      final horizontal = ScrollController();
      final vertical = ScrollController();
      addTearDown(horizontal.dispose);
      addTearDown(vertical.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Center(
              child: SizedBox(
                width: 100,
                height: 80,
                child: CLScrollable(
                  horizontalController: horizontal,
                  verticalController: vertical,
                  child: const Focus(
                    autofocus: true,
                    child: SizedBox(width: 240, height: 200),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(modifier);

      final horizontalOffset = horizontal.offset;
      expect(horizontalOffset, greaterThan(0));
      expect(vertical.offset, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(horizontal.offset, horizontalOffset);

      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(modifier);

      final verticalOffset = vertical.offset;
      expect(verticalOffset, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(horizontal.offset, horizontalOffset);
      expect(vertical.offset, verticalOffset);
    });
  }
}
