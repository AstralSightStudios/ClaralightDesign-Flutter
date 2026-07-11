import 'dart:ui' as ui;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

void main() {
  test('CLList has stable public defaults', () {
    const list = CLList(children: [SizedBox()]);

    expect(list.scrollDirection, Axis.vertical);
    expect(list.scrollbarVisibility, CLScrollbarVisibility.auto);
    expect(list.blurExtent, const EdgeInsets.all(24));
    expect(list.blurSigma, const EdgeInsets.all(16));
    expect(list.padding, EdgeInsets.zero);
    expect(list.borderRadius, BorderRadius.zero);
    expect(list.controller, isNull);
  });

  testWidgets('CLList rejects a negative blur extent', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLList(
          blurExtent: EdgeInsets.only(top: -1),
          children: [SizedBox()],
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('CLList rejects an infinite blur sigma', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CLList(
          blurSigma: EdgeInsets.only(bottom: double.infinity),
          children: [SizedBox()],
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('CLList.builder lazily builds only visible items', (
    tester,
  ) async {
    var buildCount = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: CLList.builder(
            itemBuilder: (context, index) {
              buildCount += 1;
              return SizedBox(height: 50, child: Text('$index'));
            },
            itemCount: 100,
          ),
        ),
      ),
    );

    expect(buildCount, lessThan(100));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('99'), findsNothing);
  });

  testWidgets('CLList.separated inserts separators between items', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 300,
          child: CLList.separated(
            itemBuilder: (context, index) =>
                SizedBox(height: 40, child: Text('item $index')),
            separatorBuilder: (context, index) =>
                SizedBox(height: 10, child: Text('sep $index')),
            itemCount: 3,
          ),
        ),
      ),
    );

    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);
    expect(find.text('sep 0'), findsOneWidget);
    expect(find.text('sep 1'), findsOneWidget);
    expect(find.text('sep 2'), findsNothing);
  });

  testWidgets('CLList scrolls to an external controller offset', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: CLList.builder(
            controller: controller,
            itemBuilder: (context, index) =>
                SizedBox(height: 50, child: Text('$index')),
            itemCount: 50,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    controller.jumpTo(200);
    await tester.pumpAndSettle();

    expect(controller.offset, 200);
    expect(find.text('0'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('CLList masks overflowing vertical edges', (tester) async {
    const boundaryKey = Key('vertical-boundary');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 100,
              height: 100,
              child: CLList.builder(
                blurExtent: const EdgeInsets.symmetric(vertical: 20),
                blurSigma: EdgeInsets.zero,
                scrollbarVisibility: CLScrollbarVisibility.hidden,
                itemExtent: 50,
                itemBuilder: (context, index) =>
                    const ColoredBox(color: Colors.red),
                itemCount: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var [top, bottom] = await _readPixels(
      tester,
      find.byKey(boundaryKey),
      const [Offset(50, 1), Offset(50, 98)],
    );
    expect(top.a, greaterThan(0.9));
    expect(bottom.a, lessThan(0.2));

    await tester.drag(find.byType(CLList), const Offset(0, -100));
    await tester.pumpAndSettle();
    [top, bottom] = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(50, 1),
      Offset(50, 98),
    ]);
    expect(top.a, lessThan(0.2));
    expect(bottom.a, lessThan(0.2));
  });

  testWidgets('CLList masks overflowing horizontal edges', (tester) async {
    const boundaryKey = Key('horizontal-boundary');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 100,
              height: 50,
              child: CLList.builder(
                scrollDirection: Axis.horizontal,
                blurExtent: const EdgeInsets.symmetric(horizontal: 20),
                blurSigma: EdgeInsets.zero,
                scrollbarVisibility: CLScrollbarVisibility.hidden,
                itemExtent: 50,
                itemBuilder: (context, index) =>
                    const ColoredBox(color: Colors.red),
                itemCount: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var [left, right] = await _readPixels(
      tester,
      find.byKey(boundaryKey),
      const [Offset(1, 25), Offset(98, 25)],
    );
    expect(left.a, greaterThan(0.9));
    expect(right.a, lessThan(0.2));

    await tester.drag(find.byType(CLList), const Offset(-100, 0));
    await tester.pumpAndSettle();
    [left, right] = await _readPixels(tester, find.byKey(boundaryKey), const [
      Offset(1, 25),
      Offset(98, 25),
    ]);
    expect(left.a, lessThan(0.2));
    expect(right.a, lessThan(0.2));
  });

  testWidgets('CLList hidden scrollbar stays absent', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: CLList.builder(
            scrollbarVisibility: CLScrollbarVisibility.hidden,
            itemBuilder: (context, index) =>
                SizedBox(height: 50, child: Text('$index')),
            itemCount: 50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RawScrollbar), findsNothing);
  });

  testWidgets('CLList always scrollbar is painted', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: CLList.builder(
            scrollbarVisibility: CLScrollbarVisibility.always,
            itemBuilder: (context, index) =>
                SizedBox(height: 50, child: Text('$index')),
            itemCount: 50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RawScrollbar), findsOneWidget);
  });

  testWidgets('CLList exposes vertical scroll semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: CLList.builder(
            itemBuilder: (context, index) =>
                SizedBox(height: 50, child: Text('$index')),
            itemCount: 50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CLList), const Offset(0, -100));
    await tester.pumpAndSettle();

    final node = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.hasAction(SemanticsAction.scrollUp) &&
          data.hasAction(SemanticsAction.scrollDown);
    });
    expect(node, findsOne);
    semantics.dispose();
  });

  testWidgets('CLList exposes horizontal scroll semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 50,
          child: CLList.builder(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) =>
                SizedBox(width: 50, child: Text('$index')),
            itemCount: 50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CLList), const Offset(-100, 0));
    await tester.pumpAndSettle();

    final node = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.hasAction(SemanticsAction.scrollLeft) &&
          data.hasAction(SemanticsAction.scrollRight);
    });
    expect(node, findsOne);
    semantics.dispose();
  });

  testWidgets('CLList padding contributes to scroll extent', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 200,
            child: CLList.builder(
              controller: controller,
              padding: const EdgeInsets.only(top: 20, bottom: 30),
              itemBuilder: (context, index) =>
                  SizedBox(height: 50, child: Text('$index')),
              itemCount: 5,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 5 * 50 + top 20 + bottom 30 = 300; viewport 200; max scroll = 100.
    expect(controller.position.maxScrollExtent, 100);
  });

  testWidgets('CLList switches scroll axes without stale scrollbar metrics', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    Widget build(Axis direction) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: CLList.builder(
              key: const Key('list'),
              controller: controller,
              scrollDirection: direction,
              scrollbarVisibility: CLScrollbarVisibility.always,
              itemExtent: 50,
              itemBuilder: (context, index) => Text('$index'),
              itemCount: 20,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(Axis.vertical));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(Axis.horizontal));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      axisDirectionToAxis(controller.position.axisDirection),
      Axis.horizontal,
    );
  });

  testWidgets('CLList controller updates detach external controllers safely', (
    tester,
  ) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget build(ScrollController? controller) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 100,
            child: CLList.builder(
              key: const Key('list'),
              controller: controller,
              blurExtent: EdgeInsets.zero,
              scrollbarVisibility: CLScrollbarVisibility.hidden,
              itemExtent: 40,
              itemBuilder: (context, index) => Text('$index'),
              itemCount: 10,
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

  testWidgets('CLList reverse activates the physical leading edge', (
    tester,
  ) async {
    const boundaryKey = Key('boundary');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 100,
              height: 100,
              child: CLList(
                reverse: true,
                blurExtent: EdgeInsets.symmetric(vertical: 20),
                blurSigma: EdgeInsets.zero,
                scrollbarVisibility: CLScrollbarVisibility.hidden,
                children: [
                  SizedBox(height: 500, child: ColoredBox(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final [top, bottom] = await _readPixels(
      tester,
      find.byKey(boundaryKey),
      const [Offset(50, 1), Offset(50, 98)],
    );
    expect(top.a, lessThan(0.2));
    expect(bottom.a, greaterThan(0.9));
  });
}
