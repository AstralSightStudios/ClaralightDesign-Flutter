import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _moreKey = Key('overflow-more');

void main() {
  test('CLOverflowToolbar has stable defaults', () {
    final toolbar = CLOverflowToolbar<int>(
      items: const [],
      overflowTriggerBuilder: _trigger,
    );

    expect(toolbar.spacing, 2);
    expect(toolbar.horizontalPadding, 3);
    expect(toolbar.overflowExtent, 44);
    expect(toolbar.overflowEnabled, isTrue);
    expect(toolbar.menuWidth, 260);
    expect(toolbar.menuPadding, const EdgeInsets.all(10));
    expect(toolbar.toolbarBuilder, isNull);
    expect(toolbar.onOverflowChanged, isNull);
  });

  testWidgets('all items fit without building More', (tester) async {
    final builds = <int, int>{};
    final reports = <Set<int>>[];
    final items = _items(count: 3, extent: 40, builds: builds);

    await tester.pumpWidget(
      _host(
        width: 140,
        items: items,
        onOverflowChanged: (hidden) => reports.add(hidden),
      ),
    );

    expect(find.byType(CLToolbar), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
    expect(find.byType(CLMenu), findsNothing);
    expect(find.byKey(const Key('tool-0')), findsOneWidget);
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(builds, {0: 1, 1: 1, 2: 1});
    expect(reports, [<int>{}]);
  });

  testWidgets('lowest priority items hide first and trigger receives IDs', (
    tester,
  ) async {
    Set<int>? triggerHidden;
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2, 3: 2},
    );

    await tester.pumpWidget(
      _host(
        width: 162,
        items: items,
        overflowExtent: 30,
        overflowTriggerBuilder: (context, hiddenIds, toggle) {
          triggerHidden = hiddenIds;
          return _trigger(context, hiddenIds, toggle);
        },
      ),
    );

    expect(triggerHidden, {1});
    expect(find.byKey(const Key('tool-0')), findsOneWidget);
    expect(find.byKey(const Key('tool-1')), findsNothing);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(find.byKey(const Key('tool-3')), findsOneWidget);
    expect(find.byKey(_moreKey), findsOneWidget);
  });

  testWidgets('same-priority items hide from the logical trailing edge', (
    tester,
  ) async {
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 1, 2: 1, 3: 1},
    );

    await tester.pumpWidget(
      _host(width: 162, items: items, overflowExtent: 30),
    );

    expect(find.byKey(const Key('tool-0')), findsOneWidget);
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(find.byKey(const Key('tool-3')), findsNothing);
  });

  testWidgets('disabled and selected builders still reserve their extents', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 120,
        items: [
          _item(0, extent: 40, retention: CLToolbarItemRetention.pinned),
          _item(
            1,
            extent: 40,
            priority: 5,
            toolbarBuilder: (_) => CLIconButton(
              key: const Key('disabled-selected-tool'),
              icon: Icons.star,
              selected: true,
              onPressed: null,
            ),
          ),
          _item(2, extent: 40, priority: 0),
        ],
      ),
    );

    expect(find.byKey(const Key('disabled-selected-tool')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsNothing);
    expect(find.byKey(_moreKey), findsOneWidget);
  });

  testWidgets('wider constraints restore items in their original order', (
    tester,
  ) async {
    var width = 162.0;
    late StateSetter update;
    final builds = <int, int>{};
    final reports = <Set<int>>[];
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 1, 3: 2},
      builds: builds,
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: width,
            items: items,
            overflowExtent: 30,
            onOverflowChanged: (hidden) => reports.add(hidden),
          );
        },
      ),
    );

    expect(find.byKey(const Key('tool-1')), findsNothing);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(find.byKey(const Key('tool-3')), findsOneWidget);

    update(() => width = 180);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(find.byKey(const Key('tool-3')), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
    expect(builds[1], greaterThan(0));
    expect(reports, [
      <int>{1},
      <int>{},
    ]);
  });

  testWidgets('menu keeps hidden items in original order', (tester) async {
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2, 3: 1},
    );

    await tester.pumpWidget(
      _host(width: 120, items: items, overflowExtent: 30),
    );
    await _openMenu(tester);

    final first = tester.getRect(find.byKey(const Key('menu-1')));
    final second = tester.getRect(find.byKey(const Key('menu-3')));
    expect(first.top, lessThan(second.top));
    expect(find.byKey(const Key('menu-2')), findsNothing);
  });

  testWidgets('More opens from keyboard focus with Enter and Space', (
    tester,
  ) async {
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2, 3: 1},
    );

    await tester.pumpWidget(
      _host(width: 120, items: items, overflowExtent: 30),
    );
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-1')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CLList), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-1')), findsOneWidget);
  });

  testWidgets('disabled More rejects pointer and keyboard activation', (
    tester,
  ) async {
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2, 3: 1},
    );

    await tester.pumpWidget(
      _host(
        width: 120,
        items: items,
        overflowExtent: 30,
        overflowEnabled: false,
      ),
    );
    final more = find.byKey(_moreKey);
    expect(tester.widget<GestureDetector>(more).onTap, isNull);
    expect(
      tester
          .widget<FocusableActionDetector>(
            find.ancestor(
              of: more,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(more, warnIfMissed: false);
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CLList), findsNothing);
  });

  testWidgets('disabling More closes an open menu', (tester) async {
    var overflowEnabled = true;
    late StateSetter update;
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2, 3: 1},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: 120,
            items: items,
            overflowExtent: 30,
            overflowEnabled: overflowEnabled,
          );
        },
      ),
    );
    await _openMenu(tester);
    expect(find.byType(CLList), findsOneWidget);

    update(() => overflowEnabled = false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(CLList), findsNothing);
    expect(tester.widget<GestureDetector>(find.byKey(_moreKey)).onTap, isNull);
  });

  testWidgets('allocation changes close an open menu safely', (tester) async {
    var width = 120.0;
    late StateSetter update;
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 1, 3: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, overflowExtent: 30);
        },
      ),
    );
    await _openMenu(tester);
    expect(find.byType(CLList), findsOneWidget);

    update(() => width = 180);
    await tester.pumpAndSettle();

    expect(find.byType(CLList), findsNothing);
    expect(find.byKey(_moreKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize removing More restores the previous focus', (
    tester,
  ) async {
    var width = 120.0;
    late StateSetter update;
    final previousFocus = FocusNode(debugLabel: 'before-overflow-toolbar');
    addTearDown(previousFocus.dispose);
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 1, 3: 2},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Column(
                children: [
                  TextButton(
                    key: const Key('before-overflow-toolbar'),
                    focusNode: previousFocus,
                    onPressed: () {},
                    child: const Text('Before'),
                  ),
                  SizedBox(
                    width: width,
                    child: CLOverflowToolbar<int>(
                      items: items,
                      overflowExtent: 30,
                      overflowTriggerBuilder: _trigger,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    previousFocus.requestFocus();
    await tester.pump();
    expect(previousFocus.hasFocus, isTrue);

    await _openMenu(tester);
    expect(previousFocus.hasFocus, isFalse);

    update(() => width = 180);
    await tester.pumpAndSettle();

    expect(find.byKey(_moreKey), findsNothing);
    expect(previousFocus.hasFocus, isTrue);
  });

  testWidgets('tiny widths scroll instead of hiding pinned items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 40,
        items: [
          _item(0, extent: 50, retention: CLToolbarItemRetention.pinned),
          _item(1, extent: 50, retention: CLToolbarItemRetention.pinned),
          _item(2, extent: 50),
        ],
      ),
    );

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.scrollDirection, Axis.horizontal);
    expect(find.byKey(const Key('tool-0')), findsOneWidget);
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsNothing);
    expect(find.byKey(_moreKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden toolbar widgets have no closed-menu semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final hiddenToolbarFocus = FocusNode();
    final hiddenMenuFocus = FocusNode();
    addTearDown(hiddenToolbarFocus.dispose);
    addTearDown(hiddenMenuFocus.dispose);

    await tester.pumpWidget(
      _host(
        width: 70,
        items: [
          _item(0, extent: 40, retention: CLToolbarItemRetention.pinned),
          _item(
            1,
            extent: 40,
            toolbarBuilder: (_) => Semantics(
              label: 'Hidden toolbar tool',
              child: TextButton(
                focusNode: hiddenToolbarFocus,
                onPressed: () {},
                child: const Text('Hidden toolbar tool'),
              ),
            ),
            overflowBuilder: (context, closeMenu) => TextButton(
              key: const Key('hidden-menu-tool'),
              focusNode: hiddenMenuFocus,
              onPressed: closeMenu,
              child: const Text('Hidden menu tool'),
            ),
          ),
        ],
      ),
    );

    expect(find.byKey(const Key('tool-1')), findsNothing);
    expect(find.bySemanticsLabel('Hidden toolbar tool'), findsNothing);
    expect(hiddenToolbarFocus.hasFocus, isFalse);

    await _openMenu(tester);
    expect(find.bySemanticsLabel('Hidden toolbar tool'), findsNothing);
    expect(find.bySemanticsLabel('Hidden menu tool'), findsOneWidget);
    expect(hiddenMenuFocus.hasFocus, isTrue);
    semantics.dispose();
  });

  testWidgets('RTL preserves logical and menu order', (tester) async {
    final items = _items(
      count: 4,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 1, 3: 2},
    );

    await tester.pumpWidget(
      _host(
        width: 120,
        items: items,
        overflowExtent: 30,
        textDirection: TextDirection.rtl,
      ),
    );

    expect(
      tester.getCenter(find.byKey(const Key('tool-0'))).dx,
      greaterThan(tester.getCenter(find.byKey(const Key('tool-3'))).dx),
    );

    await _openMenu(tester);
    final first = tester.getRect(find.byKey(const Key('menu-1')));
    final second = tester.getRect(find.byKey(const Key('menu-2')));
    expect(first.top, lessThan(second.top));
  });

  testWidgets('migrates outgoing item and incoming More for exactly 160ms', (
    tester,
  ) async {
    var width = 130.0;
    late StateSetter update;
    final items = _items(
      count: 3,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, overflowExtent: 30);
        },
      ),
    );
    final initialItemCenter = _logicalCenterX(
      tester,
      find.byKey(const Key('tool-1')),
    );
    final pinnedCenter = _logicalCenterX(
      tester,
      find.byKey(const Key('tool-0')),
    );

    update(() => width = 120);
    await tester.pump();

    final outgoing = find.byKey(const Key('tool-1'));
    final more = find.byKey(_moreKey);
    expect(outgoing, findsOneWidget);
    expect(more, findsOneWidget);
    expect(_opacityOf(tester, outgoing), 1);
    expect(_scaleXOf(tester, outgoing), 1);
    expect(_opacityOf(tester, more), 0);
    expect(_logicalCenterX(tester, outgoing), closeTo(initialItemCenter, 0.01));

    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacityOf(tester, outgoing), inExclusiveRange(0, 1));
    expect(_scaleXOf(tester, outgoing), inExclusiveRange(0.8, 1));
    expect(_logicalCenterX(tester, outgoing), greaterThan(initialItemCenter));
    expect(_opacityOf(tester, more), inExclusiveRange(0, 1));
    expect(
      _logicalCenterX(tester, find.byKey(const Key('tool-0'))),
      pinnedCenter,
    );

    await tester.pump(const Duration(milliseconds: 79));
    expect(outgoing, findsOneWidget);
    expect(_opacityOf(tester, outgoing), greaterThan(0));

    await tester.pump(const Duration(milliseconds: 1));
    expect(outgoing, findsNothing);
    expect(more, findsOneWidget);
    expect(_opacityOf(tester, more), 1);
  });

  testWidgets(
    'restored item emerges from More and retained geometry stays active',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var width = 120.0;
      late StateSetter update;
      final taps = <int, int>{};
      final items = [
        for (var id = 0; id < 3; id++)
          _item(
            id,
            extent: 40,
            retention: id == 0
                ? CLToolbarItemRetention.pinned
                : CLToolbarItemRetention.overflowable,
            priority: id == 1 ? 0 : 2,
            toolbarBuilder: (_) => Semantics(
              label: 'Action $id',
              button: true,
              child: GestureDetector(
                key: Key('action-$id'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps[id] = (taps[id] ?? 0) + 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _host(width: width, items: items, overflowExtent: 30);
          },
        ),
      );
      final retainedStart = tester.getCenter(find.byKey(const Key('action-2')));

      update(() => width = 130);
      await tester.pump();
      expect(find.byKey(const Key('action-1')), findsOneWidget);
      expect(_opacityOf(tester, find.byKey(const Key('action-1'))), 0);
      expect(find.bySemanticsLabel('Action 1'), findsNothing);
      expect(find.bySemanticsLabel('Action 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 80));
      final incoming = find.byKey(const Key('action-1'));
      final retained = find.byKey(const Key('action-2'));
      expect(find.byKey(const ValueKey<int>(2)), findsOneWidget);
      expect(_opacityOf(tester, incoming), inExclusiveRange(0, 1));
      expect(
        tester.getCenter(incoming).dx,
        lessThan(tester.getCenter(find.byKey(_moreKey)).dx),
      );
      expect(tester.getCenter(retained).dx, greaterThan(retainedStart.dx));
      expect(find.bySemanticsLabel('Action 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Action 2'), findsOneWidget);

      final retainedRect = tester.getRect(retained);
      final retainedSemanticsRect = _globalSemanticsRect(
        tester,
        tester.getSemantics(retained),
      );
      expect(
        retainedSemanticsRect.center.dx,
        closeTo(retainedRect.center.dx, 0.01),
      );
      await tester.tapAt(retainedRect.center);
      await tester.pump();
      expect(taps[2], 1);

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.byKey(_moreKey), findsNothing);
      expect(find.byKey(const Key('action-1')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('rapid reversal captures current visuals and caps stale layers', (
    tester,
  ) async {
    var width = 130.0;
    late StateSetter update;
    final items = _items(
      count: 3,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, overflowExtent: 30);
        },
      ),
    );

    update(() => width = 120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final beforeReverse = _logicalCenterX(
      tester,
      find.byKey(const Key('tool-1')),
    );
    final opacityBefore = _opacityOf(tester, find.byKey(const Key('tool-1')));

    update(() => width = 130);
    await tester.pump();
    expect(
      _logicalCenterX(tester, find.byKey(const Key('tool-1'))),
      closeTo(beforeReverse, 0.01),
    );
    expect(
      _opacityOf(tester, find.byKey(const Key('tool-1'))),
      closeTo(opacityBefore, 0.001),
    );
    expect(
      find.byType(PositionedDirectional).evaluate().length,
      lessThanOrEqualTo(2),
    );

    update(() => width = 120);
    await tester.pump(const Duration(milliseconds: 40));
    update(() => width = 130);
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      find.byType(PositionedDirectional).evaluate().length,
      lessThanOrEqualTo(2),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(const Key('tool-2')), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
    expect(find.byType(PositionedDirectional), findsNothing);
  });

  testWidgets('outgoing visuals are inert and semantics stay singular', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var width = 130.0;
    late StateSetter update;
    var outgoingTaps = 0;
    final items = [
      _item(0, extent: 40, retention: CLToolbarItemRetention.pinned),
      _item(
        1,
        extent: 40,
        priority: 0,
        toolbarBuilder: (_) => Semantics(
          label: 'Migrating action',
          button: true,
          child: GestureDetector(
            key: const Key('migrating-action'),
            behavior: HitTestBehavior.opaque,
            onTap: () => outgoingTaps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
      _item(2, extent: 40, priority: 2),
    ];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, overflowExtent: 30);
        },
      ),
    );
    update(() => width = 120);
    await tester.pump();

    for (var frame = 0; frame < 3; frame++) {
      if (frame > 0) await tester.pump(const Duration(milliseconds: 40));
      expect(find.bySemanticsLabel('Migrating action'), findsNothing);
      final outgoing = find.byKey(const Key('migrating-action'));
      await tester.tapAt(tester.getCenter(outgoing));
      await tester.pump();
      expect(outgoingTaps, 0);
      expect(
        find.bySemanticsLabel('More'),
        frame == 0 ? findsNothing : findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets('open-menu resize closes and snaps before close animation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var width = 120.0;
    late StateSetter update;
    final rowFocus = FocusNode();
    addTearDown(rowFocus.dispose);
    final items = [
      _item(0, extent: 40, retention: CLToolbarItemRetention.pinned),
      _item(
        1,
        extent: 40,
        priority: 0,
        overflowBuilder: (context, closeMenu) => TextButton(
          key: const Key('closing-row'),
          focusNode: rowFocus,
          onPressed: closeMenu,
          child: const Text('Closing row'),
        ),
      ),
      _item(2, extent: 40, priority: 2),
    ];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, overflowExtent: 30);
        },
      ),
    );
    await _openMenu(tester);
    expect(rowFocus.hasFocus, isTrue);

    update(() => width = 130);
    await tester.pump();

    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(find.byKey(_moreKey), findsNothing);
    expect(find.byType(PositionedDirectional), findsNothing);
    expect(find.bySemanticsLabel('Closing row'), findsNothing);
    expect(rowFocus.hasFocus, isFalse);
    semantics.dispose();
  });

  testWidgets('reduced motion and scroll fallback snap immediately', (
    tester,
  ) async {
    var width = 160.0;
    late StateSetter update;
    var reduced = true;
    final items = [
      _item(0, extent: 50, retention: CLToolbarItemRetention.pinned),
      _item(1, extent: 50, retention: CLToolbarItemRetention.pinned),
      _item(2, extent: 50),
    ];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(width: width, items: items, disableAnimations: reduced);
        },
      ),
    );
    update(() => width = 150);
    await tester.pump();
    expect(find.byKey(const Key('tool-2')), findsNothing);
    expect(find.byType(PositionedDirectional), findsNothing);

    update(() {
      reduced = false;
      width = 110;
    });
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(PositionedDirectional), findsNothing);
    expect(find.byKey(const Key('tool-0')), findsOneWidget);
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
  });

  testWidgets('RTL and custom shell use declared logical geometry', (
    tester,
  ) async {
    var width = 144.0;
    late StateSetter update;
    final items = _items(
      count: 3,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: width,
            items: items,
            overflowExtent: 30,
            spacing: 5,
            horizontalPadding: 7,
            textDirection: TextDirection.rtl,
            toolbarBuilder: (context, children) => SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < children.length; index++) ...[
                      if (index > 0) const SizedBox(width: 5),
                      children[index],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final oldCenter = _rtlLogicalCenterX(
      tester,
      find.byKey(const Key('tool-1')),
    );

    update(() => width = 134);
    await tester.pump();
    expect(
      _rtlLogicalCenterX(tester, find.byKey(const Key('tool-1'))),
      closeTo(oldCenter, 0.01),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      _rtlLogicalCenterX(tester, find.byKey(const Key('tool-1'))),
      greaterThan(oldCenter),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('tool-1')), findsNothing);
  });

  testWidgets('target reports and order update before visual completion', (
    tester,
  ) async {
    var width = 130.0;
    late StateSetter update;
    final reports = <Set<int>>[];
    final items = _items(
      count: 3,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: width,
            items: items,
            overflowExtent: 30,
            onOverflowChanged: reports.add,
          );
        },
      ),
    );
    expect(reports, [<int>{}]);

    update(() => width = 120);
    await tester.pump();
    expect(reports, [
      <int>{},
      <int>{1},
    ]);
    expect(find.byKey(const Key('tool-1')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('tool-0'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('tool-2'))).dx),
    );
    await tester.pump(const Duration(milliseconds: 160));
    expect(
      tester.getCenter(find.byKey(const Key('tool-2'))).dx,
      lessThan(tester.getCenter(find.byKey(_moreKey)).dx),
    );
  });

  testWidgets('configuration changes and unchanged membership snap', (
    tester,
  ) async {
    var width = 130.0;
    var extent = 40.0;
    late StateSetter update;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: width,
            items: _items(
              count: 3,
              extent: extent,
              pinnedIds: const {0},
              priorities: const {1: 0, 2: 2},
            ),
            overflowExtent: 30,
          );
        },
      ),
    );

    update(() => extent = 45);
    await tester.pump();
    expect(find.byKey(const Key('tool-1')), findsNothing);
    expect(find.byKey(_moreKey), findsOneWidget);
    expect(find.byType(PositionedDirectional), findsNothing);

    final moreCenter = _logicalCenterX(tester, find.byKey(_moreKey));
    update(() => width = 131);
    await tester.pump();
    expect(find.byType(PositionedDirectional), findsNothing);
    expect(_logicalCenterX(tester, find.byKey(_moreKey)), moreCenter);
  });

  testWidgets('disabled outgoing More is visual-only with a null toggle', (
    tester,
  ) async {
    var width = 120.0;
    late StateSetter update;
    final toggles = <VoidCallback?>[];
    final hiddenSets = <Set<int>>[];
    final items = _items(
      count: 3,
      extent: 40,
      pinnedIds: const {0},
      priorities: const {1: 0, 2: 2},
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            width: width,
            items: items,
            overflowExtent: 30,
            overflowEnabled: false,
            overflowTriggerBuilder: (context, hiddenIds, toggle) {
              toggles.add(toggle);
              hiddenSets.add(hiddenIds);
              return _trigger(context, hiddenIds, toggle);
            },
          );
        },
      ),
    );

    update(() => width = 130);
    await tester.pump();
    expect(find.byType(CLMenu), findsNothing);
    expect(find.byKey(_moreKey), findsOneWidget);
    expect(toggles, everyElement(isNull));
    expect(hiddenSets, everyElement(<int>{1}));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(CLMenu), findsNothing);
    expect(toggles, everyElement(isNull));
  });

  test('duplicate IDs, invalid extents, and missing builders assert', () {
    final duplicate = _item(1, retention: CLToolbarItemRetention.pinned);
    expect(
      () => CLOverflowToolbar<int>(
        items: [duplicate, duplicate],
        overflowTriggerBuilder: _trigger,
      ),
      throwsAssertionError,
    );
    expect(
      () => CLOverflowToolbarItem<int>(
        id: 1,
        extent: 0,
        retention: CLToolbarItemRetention.pinned,
        toolbarBuilder: (_) => const SizedBox(),
      ),
      throwsAssertionError,
    );
    expect(
      () => CLOverflowToolbarItem<int>(
        id: 1,
        extent: double.infinity,
        retention: CLToolbarItemRetention.pinned,
        toolbarBuilder: (_) => const SizedBox(),
      ),
      throwsAssertionError,
    );
    expect(
      () => CLOverflowToolbarItem<int>(
        id: 1,
        extent: 20,
        retention: CLToolbarItemRetention.overflowable,
        toolbarBuilder: (_) => const SizedBox(),
      ),
      throwsAssertionError,
    );
  });
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(_moreKey));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

Widget _host({
  required double width,
  required List<CLOverflowToolbarItem<int>> items,
  TextDirection textDirection = TextDirection.ltr,
  double overflowExtent = 30,
  CLOverflowToolbarTriggerBuilder<int> overflowTriggerBuilder = _trigger,
  bool overflowEnabled = true,
  bool disableAnimations = false,
  double spacing = 2,
  double horizontalPadding = 3,
  CLOverflowToolbarBuilder? toolbarBuilder,
  ValueChanged<Set<int>>? onOverflowChanged,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                key: const Key('overflow-host'),
                width: width,
                child: CLOverflowToolbar<int>(
                  items: items,
                  overflowTriggerBuilder: overflowTriggerBuilder,
                  toolbarBuilder: toolbarBuilder,
                  spacing: spacing,
                  horizontalPadding: horizontalPadding,
                  overflowExtent: overflowExtent,
                  overflowEnabled: overflowEnabled,
                  onOverflowChanged: onOverflowChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _globalSemanticsRect(WidgetTester tester, SemanticsNode node) {
  var globalTransform = node.transform ?? Matrix4.identity();
  for (
    SemanticsNode? parent = node.parent;
    parent != null;
    parent = parent.parent
  ) {
    if (parent.transform != null) {
      globalTransform = parent.transform!.multiplied(globalTransform);
    }
  }
  final physicalRect = MatrixUtils.transformRect(globalTransform, node.rect);
  final pixelRatio = tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    physicalRect.left / pixelRatio,
    physicalRect.top / pixelRatio,
    physicalRect.right / pixelRatio,
    physicalRect.bottom / pixelRatio,
  );
}

double _logicalCenterX(WidgetTester tester, Finder child) {
  return tester.getCenter(child).dx -
      tester.getTopLeft(find.byKey(const Key('overflow-host'))).dx;
}

double _rtlLogicalCenterX(WidgetTester tester, Finder child) {
  return tester.getTopRight(find.byKey(const Key('overflow-host'))).dx -
      tester.getCenter(child).dx;
}

double _opacityOf(WidgetTester tester, Finder child) {
  final opacities = tester
      .widgetList<Opacity>(
        find.ancestor(of: child, matching: find.byType(Opacity)),
      )
      .map((opacity) => opacity.opacity);
  return opacities.reduce((first, second) => first < second ? first : second);
}

double _scaleXOf(WidgetTester tester, Finder child) {
  final transforms = tester.widgetList<Transform>(
    find.ancestor(of: child, matching: find.byType(Transform)),
  );
  return transforms
      .map((transform) => transform.transform.storage[0])
      .firstWhere((scale) => scale != 1, orElse: () => 1);
}

Widget _trigger(
  BuildContext context,
  Set<int> hiddenIds,
  VoidCallback? toggle,
) {
  return Semantics(
    label: 'More',
    button: true,
    selected: hiddenIds.isNotEmpty,
    child: GestureDetector(
      key: _moreKey,
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: const SizedBox(
        width: 30,
        height: 40,
        child: Icon(Icons.more_horiz),
      ),
    ),
  );
}

List<CLOverflowToolbarItem<int>> _items({
  required int count,
  double extent = 40,
  Set<int> pinnedIds = const {0},
  Map<int, int> priorities = const {},
  Map<int, int>? builds,
}) {
  return [
    for (var id = 0; id < count; id++)
      _item(
        id,
        extent: extent,
        retention: pinnedIds.contains(id)
            ? CLToolbarItemRetention.pinned
            : CLToolbarItemRetention.overflowable,
        priority: priorities[id] ?? id,
        builds: builds,
      ),
  ];
}

CLOverflowToolbarItem<int> _item(
  int id, {
  double extent = 40,
  CLToolbarItemRetention retention = CLToolbarItemRetention.overflowable,
  int priority = 0,
  Map<int, int>? builds,
  WidgetBuilder? toolbarBuilder,
  CLOverflowToolbarOverflowBuilder? overflowBuilder,
}) {
  return CLOverflowToolbarItem<int>(
    id: id,
    extent: extent,
    retention: retention,
    overflowPriority: priority,
    toolbarBuilder:
        toolbarBuilder ??
        (context) {
          builds?[id] = (builds[id] ?? 0) + 1;
          return Semantics(
            label: 'Toolbar $id',
            child: TextButton(
              key: Key('tool-$id'),
              onPressed: () {},
              child: Text('$id'),
            ),
          );
        },
    overflowBuilder: retention == CLToolbarItemRetention.pinned
        ? overflowBuilder
        : overflowBuilder ??
              (context, closeMenu) => TextButton(
                key: Key('menu-$id'),
                onPressed: closeMenu,
                child: Text('Menu $id'),
              ),
  );
}
