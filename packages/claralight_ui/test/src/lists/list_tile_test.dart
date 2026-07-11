import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 272, child: child)),
      ),
    );
  }

  testWidgets('CLListTile matches the Figma row geometry', (
    WidgetTester tester,
  ) async {
    const tileKey = Key('tile');
    const leadingKey = Key('leading');

    await tester.pumpWidget(
      host(
        CLListTile(
          key: tileKey,
          label: '组 2',
          leading: const SizedBox(key: leadingKey, width: 18, height: 18),
          expanded: true,
          onExpandedChanged: (_) {},
        ),
      ),
    );

    final tileRect = tester.getRect(find.byKey(tileKey));
    final leadingRect = tester.getRect(find.byKey(leadingKey));
    final labelRect = tester.getRect(find.text('组 2'));
    final disclosureRect = tester.getRect(find.byType(AnimatedRotation));

    expect(tileRect.size, const Size(272, 35));
    expect(leadingRect.left - tileRect.left, 8);
    expect(labelRect.left - leadingRect.right, 10);
    expect(disclosureRect.size, const Size(11.5, 6.5));
    expect(disclosureRect.center.dx, tileRect.right - 16);
  });

  testWidgets('CLListTile depth adds a guide slot before the leading icon', (
    WidgetTester tester,
  ) async {
    const tileKey = Key('tile');
    const leadingKey = Key('leading');

    await tester.pumpWidget(
      host(
        const CLListTile(
          key: tileKey,
          label: '进度条 1',
          depth: 1,
          leading: SizedBox(key: leadingKey, width: 18, height: 18),
        ),
      ),
    );

    final tileRect = tester.getRect(find.byKey(tileKey));
    final leadingRect = tester.getRect(find.byKey(leadingKey));
    final labelRect = tester.getRect(find.text('进度条 1'));

    expect(leadingRect.left - tileRect.left, 32);
    expect(labelRect.left - leadingRect.right, 10);
  });

  testWidgets('CLListTile uses regular secondary text and primary icons', (
    WidgetTester tester,
  ) async {
    const leadingKey = Key('leading');
    final theme = CLThemeData();

    await tester.pumpWidget(
      host(
        const CLListTile(
          label: 'Frame 114',
          selected: true,
          leading: Icon(Icons.image_outlined, key: leadingKey),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Frame 114'));
    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byKey(leadingKey),
            matching: find.byType(IconTheme),
          )
          .first,
    );

    expect(label.style?.fontSize, 14);
    expect(label.style?.fontWeight, FontWeight.w400);
    expect(label.style?.letterSpacing, -0.5);
    expect(label.style?.color, theme.colors.textSecondary);
    expect(iconTheme.data.color, theme.colors.textPrimary);
  });

  testWidgets('CLListTile tint colors the label and leading icon', (
    WidgetTester tester,
  ) async {
    const leadingKey = Key('leading');
    const tint = Color(0xFFBE93E4);

    await tester.pumpWidget(
      host(
        const CLListTile(
          label: '容器 1',
          tint: tint,
          leading: Icon(Icons.grid_view_rounded, key: leadingKey),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('容器 1'));
    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byKey(leadingKey),
            matching: find.byType(IconTheme),
          )
          .first,
    );

    expect(label.style?.color, tint);
    expect(iconTheme.data.color, tint);
  });

  testWidgets('CLListTile disclosure reports the next expanded state', (
    WidgetTester tester,
  ) async {
    bool? nextState;

    await tester.pumpWidget(
      host(
        CLListTile(
          label: '组 2',
          expanded: true,
          onExpandedChanged: (value) => nextState = value,
        ),
      ),
    );

    final disclosure = tester.widget<AnimatedRotation>(
      find.byType(AnimatedRotation),
    );
    expect(disclosure.turns, 0.5);

    await tester.tap(find.byType(AnimatedRotation));
    await tester.pump();

    expect(nextState, isFalse);
  });

  testWidgets('CLListSection keeps its compact two-pixel spacing', (
    WidgetTester tester,
  ) async {
    const firstKey = Key('first');
    const secondKey = Key('second');

    await tester.pumpWidget(
      host(
        const CLListSection(
          children: [
            CLListTile(key: firstKey, label: 'Frame 114'),
            CLListTile(key: secondKey, label: '图组 1'),
          ],
        ),
      ),
    );

    final firstRect = tester.getRect(find.byKey(firstKey));
    final secondRect = tester.getRect(find.byKey(secondKey));

    expect(secondRect.top - firstRect.bottom, 2);
  });

  testWidgets('CLTreeView keeps its layout through CLList', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const treeKey = Key('tree');
    const firstKey = Key('first');
    const secondKey = Key('second');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: treeKey,
              width: 282,
              height: 316,
              child: CLTreeView(
                controller: controller,
                children: const [
                  CLListTile(key: firstKey, label: 'Frame 114'),
                  CLListTile(key: secondKey, label: '图组 1'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final treeRect = tester.getRect(find.byKey(treeKey));
    final firstRect = tester.getRect(find.byKey(firstKey));
    final secondRect = tester.getRect(find.byKey(secondKey));
    final list = tester.widget<CLList>(find.byType(CLList));

    expect(treeRect.size, const Size(282, 316));
    expect(firstRect, Rect.fromLTWH(treeRect.left, treeRect.top + 4, 272, 35));
    expect(secondRect.top - firstRect.bottom, 4);
    expect(list.scrollDirection, Axis.vertical);
    expect(list.controller, same(controller));
    expect(
      list.padding,
      const EdgeInsets.only(top: 4, right: 10, bottom: 4),
    );
    expect(list.scrollbarVisibility, CLScrollbarVisibility.auto);
    expect(list.blurExtent, const EdgeInsets.all(24));
    expect(list.blurSigma, const EdgeInsets.all(16));
  });
}
