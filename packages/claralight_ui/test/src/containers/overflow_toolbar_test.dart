import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
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
  ValueChanged<Set<int>>? onOverflowChanged,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CLOverflowToolbar<int>(
              items: items,
              overflowTriggerBuilder: overflowTriggerBuilder,
              overflowExtent: overflowExtent,
              overflowEnabled: overflowEnabled,
              onOverflowChanged: onOverflowChanged,
            ),
          ),
        ),
      ),
    ),
  );
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
