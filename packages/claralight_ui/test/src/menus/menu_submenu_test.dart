import 'dart:ui' show Tristate;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildMenu({
    required CLMenuController controller,
    Alignment alignment = Alignment.center,
    bool disableAnimations = false,
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    List<Widget>? children,
  }) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              viewPadding: viewPadding,
              viewInsets: viewInsets,
            ),
            child: Align(
              alignment: alignment,
              child: CLMenu(
                controller: controller,
                anchor: const Icon(Icons.more_horiz),
                children:
                    children ??
                    const [
                      CLMenuSubmenu(
                        label: 'Level 1',
                        children: [
                          CLMenuSubmenu(
                            label: 'Level 2',
                            children: [
                              CLListTile(key: Key('leaf'), label: 'Leaf'),
                            ],
                          ),
                        ],
                      ),
                    ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder rowFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(CLListTile));

  Finder frostedPanels() =>
      find.byWidgetPredicate((widget) => widget is CLSurface && widget.frosted);

  Future<void> openRoot(
    WidgetTester tester,
    CLMenuController controller,
  ) async {
    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  test('CLMenuSubmenu has stable public defaults', () {
    const submenu = CLMenuSubmenu(label: 'More', children: [SizedBox()]);

    expect(submenu.leading, isNull);
    expect(submenu.tint, isNull);
    expect(submenu.size, CLControlSize.medium);
    expect(submenu.labelMaxLines, 1);
  });

  testWidgets('empty submenu is inert and hides its disclosure arrow', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: const [CLMenuSubmenu(label: 'Empty', children: [])],
      ),
    );
    await openRoot(tester, controller);

    final tile = tester.widget<CLListTile>(rowFor('Empty'));
    expect(tile.trailing, isNull);
    expect(tile.onTap, isNull);
    await tester.tap(find.text('Empty'));
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsOneWidget);
  });

  testWidgets('pushes arbitrary depth and each header pops one level', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);

    expect(frostedPanels(), findsOneWidget);
    await tester.tap(find.text('Level 1'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(frostedPanels(), findsNWidgets(2));
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);

    await tester.tap(find.text('Level 2'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(frostedPanels(), findsNWidgets(3));
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.byKey(const Key('leaf')), findsOneWidget);
    expect(controller.isOpen, isTrue);

    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNWidgets(2));
    expect(find.byKey(const Key('leaf')), findsNothing);
    expect(find.text('Level 2'), findsOneWidget);

    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(controller.isOpen, isTrue);
  });

  testWidgets(
    'tapping an exposed parent surface pops one level while outside closes all',
    (tester) async {
      final controller = CLMenuController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        buildMenu(
          controller: controller,
          children: const [
            CLMenuSubmenu(
              label: 'Child',
              children: [CLListTile(label: 'Nested item')],
            ),
            CLListTile(label: 'Root item 1'),
            CLListTile(label: 'Root item 2'),
            CLListTile(label: 'Root item 3'),
            CLListTile(label: 'Root item 4'),
          ],
        ),
      );
      await openRoot(tester, controller);
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();

      expect(frostedPanels(), findsNWidgets(2));
      final parentRect = tester.getRect(frostedPanels().first);
      final childRect = tester.getRect(frostedPanels().last);
      final parentTap = Offset(parentRect.center.dx, parentRect.bottom - 8);
      expect(parentRect.contains(parentTap), isTrue);
      expect(childRect.contains(parentTap), isFalse);

      await tester.tapAt(parentTap);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(frostedPanels(), findsOneWidget);

      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(frostedPanels(), findsNothing);
    },
  );

  testWidgets('isolates the trigger from parent retreat at every frame', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);

    final sourceRect = tester.getRect(rowFor('Level 1'));
    await tester.tap(find.text('Level 1'));
    await tester.pump();
    await tester.pump();

    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 24));
      final headerRect = tester.getRect(rowFor('Level 1'));
      expect(headerRect.left, closeTo(sourceRect.left, 0.1));
      expect(headerRect.top, closeTo(sourceRect.top, 0.1));
      expect(headerRect.width, closeTo(sourceRect.width, 0.1));
      expect(headerRect.height, closeTo(sourceRect.height, 0.1));
    }
    await tester.pumpAndSettle();

    final level2Source = tester.getRect(rowFor('Level 2'));
    await tester.tap(find.text('Level 2'));
    await tester.pump();
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 24));
      final headerRect = tester.getRect(rowFor('Level 2'));
      expect(headerRect.left, closeTo(level2Source.left, 0.1));
      expect(headerRect.top, closeTo(level2Source.top, 0.1));
      expect(headerRect.width, closeTo(level2Source.width, 0.1));
      expect(headerRect.height, closeTo(level2Source.height, 0.1));
    }
  });

  testWidgets('Escape and system Back close the complete submenu stack', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(frostedPanels(), findsNothing);

    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(frostedPanels(), findsNothing);
  });

  testWidgets('clamps an oversized submenu above viewInsets', (tester) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        alignment: Alignment.bottomRight,
        viewPadding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
        viewInsets: const EdgeInsets.only(bottom: 80),
        children: [
          CLMenuSubmenu(
            label: 'Overflow',
            children: [
              for (var i = 0; i < 12; i++) CLListTile(label: 'Item $i'),
            ],
          ),
        ],
      ),
    );
    await openRoot(tester, controller);
    await tester.tap(find.text('Overflow'));
    await tester.pumpAndSettle();

    final childRect = tester.getRect(frostedPanels().last);
    expect(childRect.left, greaterThanOrEqualTo(20));
    expect(childRect.top, greaterThanOrEqualTo(32));
    expect(childRect.right, lessThanOrEqualTo(300));
    expect(childRect.bottom, lessThanOrEqualTo(208));
    expect(find.text('Overflow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps every ancestor visible with cumulative retreat', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((widget) => widget.opacity),
      contains(closeTo(0.72, 0.001)),
    );
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();

    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((widget) => widget.opacity)
        .toList();
    expect(opacities, contains(closeTo(0.72, 0.001)));
    expect(opacities, contains(closeTo(0.5184, 0.001)));
    final rootSurfaceAncestorOpacities = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: frostedPanels().first,
            matching: find.byType(Opacity),
          ),
        )
        .map((widget) => widget.opacity);
    expect(
      rootSurfaceAncestorOpacities.any(
        (opacity) =>
            (opacity - 0.72).abs() < 0.001 || (opacity - 0.5184).abs() < 0.001,
      ),
      isFalse,
    );
    expect(frostedPanels(), findsNWidgets(3));
  });

  testWidgets('new ancestors join one root-anchored retreat transform', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();

    final firstDepthRects = [
      tester.getRect(frostedPanels().at(0)),
      tester.getRect(frostedPanels().at(1)),
    ];
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();
    final secondDepthRects = [
      tester.getRect(frostedPanels().at(0)),
      tester.getRect(frostedPanels().at(1)),
    ];

    expect(
      secondDepthRects[0].width / firstDepthRects[0].width,
      closeTo(0.96, 0.001),
    );
    expect(
      secondDepthRects[1].width / firstDepthRects[1].width,
      closeTo(0.96, 0.001),
    );
    expect(
      secondDepthRects[0].height / firstDepthRects[0].height,
      closeTo(0.96, 0.001),
    );
    expect(
      secondDepthRects[1].height / firstDepthRects[1].height,
      closeTo(0.96, 0.001),
    );
  });

  testWidgets('global close merges child surfaces into the root morph', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(frostedPanels(), findsNWidgets(3));
    for (var i = 1; i < 3; i++) {
      final surface = tester.widget<CLSurface>(frostedPanels().at(i));
      expect(surface.frostSigma, lessThanOrEqualTo(1));
      expect(surface.fill!.a, lessThanOrEqualTo(0.01));
    }
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNothing);
  });

  testWidgets('ancestor state stays mounted until its own page is popped', (
    tester,
  ) async {
    var initCount = 0;
    var disposeCount = 0;
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          CLMenuSubmenu(
            label: 'Stateful level',
            children: [
              _LifecycleProbe(
                onInit: () => initCount++,
                onDispose: () => disposeCount++,
              ),
              const CLMenuSubmenu(
                label: 'Nested level',
                children: [CLListTile(label: 'Nested leaf')],
              ),
            ],
          ),
        ],
      ),
    );
    await openRoot(tester, controller);
    await tester.tap(find.text('Stateful level'));
    await tester.pumpAndSettle();
    expect(initCount, 1);
    expect(disposeCount, 0);

    await tester.tap(find.text('Nested level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nested level'));
    await tester.pumpAndSettle();
    expect(initCount, 1);
    expect(disposeCount, 0);

    await tester.tap(find.text('Stateful level'));
    await tester.pumpAndSettle();
    expect(disposeCount, 1);
  });

  testWidgets('header pop restores focus to the original trigger', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNWidgets(2));
  });

  testWidgets('an open submenu reflects updated children', (tester) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    late StateSetter update;
    var childLabel = 'Original child';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return buildMenu(
            controller: controller,
            children: [
              CLMenuSubmenu(
                label: 'Dynamic level',
                children: [CLListTile(label: childLabel)],
              ),
            ],
          );
        },
      ),
    );
    await openRoot(tester, controller);
    await tester.tap(find.text('Dynamic level'));
    await tester.pumpAndSettle();
    expect(find.text('Original child'), findsOneWidget);

    update(() => childLabel = 'Updated child');
    await tester.pump();
    await tester.pump();
    expect(find.text('Updated child'), findsOneWidget);
    expect(find.text('Original child'), findsNothing);
  });

  testWidgets('keyboard focus and semantics stay on the active page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);

    expect(find.bySemanticsLabel('Level 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNWidgets(2));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Level 1'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(frostedPanels(), findsNWidgets(3));
    expect(_semanticsTreeHasLabel(tester, 'Level 1'), isFalse);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Level 2'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets(
    'rapid double tap keeps the submenu open and outside closes all',
    (tester) async {
      final controller = CLMenuController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(buildMenu(controller: controller));
      await openRoot(tester, controller);

      await tester.tap(find.text('Level 1'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('Level 1'));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      expect(frostedPanels(), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Level 1'));
      await tester.pumpAndSettle();
      expect(frostedPanels(), findsOneWidget);
      await tester.tap(find.text('Level 1'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(frostedPanels(), findsNothing);
    },
  );

  testWidgets('switching to reduced motion snaps an active submenu geometry', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildMenu(controller: controller));
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final partialRect = tester.getRect(frostedPanels().last);

    await tester.pumpWidget(
      buildMenu(controller: controller, disableAnimations: true),
    );
    await tester.pump();
    final snappedRect = tester.getRect(frostedPanels().last);
    expect(snappedRect, isNot(partialRect));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(frostedPanels().last), snappedRect);
  });

  testWidgets('reduced motion keeps final submenu geometry fixed', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(controller: controller, disableAnimations: true),
    );
    await openRoot(tester, controller);
    await tester.tap(find.text('Level 1'));
    await tester.pump();
    await tester.pump();

    final initialRect = tester.getRect(frostedPanels().last);
    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getRect(frostedPanels().last), initialRect);
    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.getRect(frostedPanels().last), initialRect);
  });
}

bool _semanticsTreeHasLabel(WidgetTester tester, String label) {
  final root =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;
  var found = false;

  void visit(SemanticsNode node) {
    if (node.getSemanticsData().label.contains(label)) found = true;
    node.visitChildren((child) {
      visit(child);
      return !found;
    });
  }

  visit(root);
  return found;
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 35);
}
