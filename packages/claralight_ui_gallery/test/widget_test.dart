import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui_gallery/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(CLScrollable.precache);

  testWidgets('Gallery shows the Claralight component sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    expect(find.text('Claralight UI'), findsOneWidget);
    expect(find.text('CLButton'), findsOneWidget);
    expect(find.text('CLToggle'), findsOneWidget);
    expect(find.text('CLSegmentedControl'), findsOneWidget);
    expect(find.text('CLDialog'), findsOneWidget);
    expect(find.text('CLMenu'), findsOneWidget);
    expect(find.byType(CLButton), findsWidgets);
    expect(find.byType(CLToggle), findsWidgets);
    expect(find.byType(CLSegmentedControl), findsWidgets);
    expect(find.byType(CLColorSwatchGroup), findsWidgets);
    expect(find.byType(CLProgressBar), findsWidgets);
    expect(find.byType(CLMenu), findsWidgets);
    expect(find.byType(CLTreeView), findsOneWidget);

    final galleryScroll = tester.widget<CLScrollable>(
      find.byKey(const Key('gallery-scroll')),
    );
    expect(galleryScroll.direction, CLScrollDirection.vertical);
    expect(galleryScroll.horizontalScrollbar, CLScrollbarVisibility.hidden);
    expect(
      tester.getSize(find.byKey(const Key('gallery-scroll'))).width,
      tester.getSize(find.byType(SafeArea)).width,
    );

    final tree = tester.widget<CLTreeView>(find.byType(CLTreeView));
    final subtreeLeaf = tree.children.singleWhere(
      (tile) => tile.label == '矩形 1',
    );
    expect(subtreeLeaf.depth, 2);
  });

  testWidgets('Gallery switches between dark and light themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    CLTheme theme() => tester.widget<CLTheme>(find.byType(CLTheme));

    expect(theme().data.colors.brightness, Brightness.dark);

    final modeControl = find.byKey(const Key('theme-mode-control'));
    await tester.tap(
      find.descendant(of: modeControl, matching: find.text('浅色')),
    );
    await tester.pump();

    expect(theme().data.colors.brightness, Brightness.light);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const CLColorScheme.light().background,
    );

    await tester.tap(
      find.descendant(of: modeControl, matching: find.text('深色')),
    );
    await tester.pump();

    expect(theme().data.colors.brightness, Brightness.dark);
  });

  testWidgets('Gallery exposes a 500-option aligned select demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    final selectFinder = find.byKey(const Key('large-select-demo'));
    final select = tester.widget<CLSelect<int>>(selectFinder);
    expect(select.options, hasLength(500));
    expect(select.value, 249);
    expect(select.alignSelectedOption, isTrue);
    expect(select.options.first.label, '项目 001 / 500');
    expect(select.options.last.label, '项目 500 / 500');
  });

  testWidgets('Gallery toolbar demo previews and switches its active tool', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    final first = find.byKey(const Key('toolbar-tool-0'));
    final initial = find.byKey(const Key('toolbar-tool-3'));
    expect(tester.widget<CLIconButton>(initial).selected, isTrue);
    expect(tester.widget<CLIconButton>(first).selected, isFalse);

    await tester.ensureVisible(first);
    await tester.pump();
    await tester.tap(first);
    await tester.pump();

    expect(tester.widget<CLIconButton>(first).selected, isTrue);
    expect(tester.widget<CLIconButton>(initial).selected, isFalse);
  });

  testWidgets('Gallery exposes the interactive CLScrollable demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    expect(find.text('CLScrollable'), findsOneWidget);
    final directionControl = find.byKey(
      const Key('scrollable-direction-control'),
    );
    final visibilityControl = find.byKey(
      const Key('scrollable-visibility-control'),
    );
    expect(
      find.descendant(of: directionControl, matching: find.text('双轴')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: visibilityControl, matching: find.text('自动')),
      findsOneWidget,
    );
    final demo = tester.widget<CLScrollable>(
      find.byKey(const Key('scrollable-demo')),
    );
    expect(demo.direction, CLScrollDirection.both);
    expect(demo.horizontalScrollbar, CLScrollbarVisibility.auto);
    expect(demo.verticalScrollbar, CLScrollbarVisibility.auto);

    await tester.ensureVisible(directionControl);
    await tester.pump();
    await tester.tap(
      find.descendant(of: directionControl, matching: find.text('横向')),
    );
    await tester.pump();
    await tester.ensureVisible(visibilityControl);
    await tester.pump();
    await tester.tap(
      find.descendant(of: visibilityControl, matching: find.text('始终')),
    );
    await tester.pump();

    final updatedDemo = tester.widget<CLScrollable>(
      find.byKey(const Key('scrollable-demo')),
    );
    expect(updatedDemo.direction, CLScrollDirection.horizontal);
    expect(updatedDemo.horizontalScrollbar, CLScrollbarVisibility.always);
    expect(updatedDemo.verticalScrollbar, CLScrollbarVisibility.always);
  });

  testWidgets('Gallery exposes the interactive CLList demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('list-demo')));
    final demo = tester.widget<CLList>(find.byKey(const Key('list-demo')));
    expect(demo.scrollDirection, Axis.vertical);
    expect(demo.scrollbarVisibility, CLScrollbarVisibility.auto);
    expect(find.text('#001'), findsOneWidget);

    final directionControl = find.byKey(const Key('list-direction-control'));
    await tester.ensureVisible(directionControl);
    await tester.pump();
    await tester.tap(
      find.descendant(of: directionControl, matching: find.text('横向')),
    );
    await tester.pump();

    final visibilityControl = find.byKey(const Key('list-visibility-control'));
    await tester.ensureVisible(visibilityControl);
    await tester.pump();
    await tester.tap(
      find.descendant(of: visibilityControl, matching: find.text('始终')),
    );
    await tester.pump();

    final updatedDemo = tester.widget<CLList>(
      find.byKey(const Key('list-demo')),
    );
    expect(updatedDemo.scrollDirection, Axis.horizontal);
    expect(updatedDemo.scrollbarVisibility, CLScrollbarVisibility.always);
  });
}
