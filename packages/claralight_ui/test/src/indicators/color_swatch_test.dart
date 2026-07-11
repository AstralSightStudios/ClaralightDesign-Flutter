import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colors = <Color>[
    Color(0xFFF04444),
    Color(0xFFF59E0B),
    Color(0xFF84CC16),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  Widget host(Widget child, {double width = 120}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  Finder selectedSwatch() {
    return find.byWidgetPredicate(
      (widget) => widget is CLColorSwatchItem && widget.selected,
    );
  }

  void expectFullyVisible(WidgetTester tester, Finder item) {
    final listRect = tester.getRect(find.byType(CLList));
    final itemRect = tester.getRect(item);

    expect(itemRect.left, greaterThanOrEqualTo(listRect.left - 0.01));
    expect(itemRect.right, lessThanOrEqualTo(listRect.right + 0.01));
  }

  testWidgets('CLColorSwatchGroup uses one horizontal CLList row', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CLColorSwatchGroup(colors: colors, selectedIndex: 0, onChanged: (_) {}),
      ),
    );
    await tester.pump();

    final list = tester.widget<CLList>(find.byType(CLList));
    expect(list.scrollDirection, Axis.horizontal);
    expect(list.scrollbarVisibility, CLScrollbarVisibility.hidden);
    expect(tester.getSize(find.byType(CLColorSwatchGroup)).height, 31);

    final swatchCenters = tester
        .widgetList<CLColorSwatchItem>(find.byType(CLColorSwatchItem))
        .map((swatch) => find.byWidget(swatch))
        .map(tester.getCenter)
        .toList();
    expect(swatchCenters, isNotEmpty);
    expect(swatchCenters.map((center) => center.dy).toSet(), hasLength(1));
  });

  testWidgets('CLColorSwatchGroup reveals its initial selection immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CLColorSwatchGroup(
          colors: colors,
          selectedIndex: colors.length - 1,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    final list = tester.widget<CLList>(find.byType(CLList));
    expect(list.controller!.offset, greaterThan(0));
    expectFullyVisible(tester, selectedSwatch());
  });

  testWidgets('CLColorSwatchGroup animates a new selection into view', (
    tester,
  ) async {
    final selectedIndex = ValueNotifier<int?>(null);
    addTearDown(selectedIndex.dispose);

    await tester.pumpWidget(
      host(
        ValueListenableBuilder<int?>(
          valueListenable: selectedIndex,
          builder: (context, value, child) {
            return CLColorSwatchGroup(
              colors: colors,
              selectedIndex: value,
              onChanged: (_) {},
            );
          },
        ),
      ),
    );

    selectedIndex.value = colors.length - 1;
    await tester.pump();

    final list = tester.widget<CLList>(find.byType(CLList));
    expect(list.controller!.position.isScrollingNotifier.value, isTrue);

    await tester.pumpAndSettle();
    expectFullyVisible(tester, selectedSwatch());
  });
}
