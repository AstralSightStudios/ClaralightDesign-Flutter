import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _anchorKey = Key('menu-anchor');
const _rowKey = Key('menu-row');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildMenu({
    required List<Widget> children,
    CLMenuController? controller,
    ValueChanged<bool>? onOpenChanged,
    Alignment alignment = Alignment.center,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Align(
              alignment: alignment,
              child: CLMenu(
                controller: controller,
                onOpenChanged: onOpenChanged,
                anchor: const Icon(Icons.more_horiz, key: _anchorKey),
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder menuPanel() =>
      find.byWidgetPredicate((widget) => widget is CLSurface && widget.frosted);

  Rect globalSemanticsRect(WidgetTester tester, SemanticsNode node) {
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

  void expectAnchoredCorner(
    WidgetTester tester,
    Alignment alignment, {
    double tolerance = 0.01,
  }) {
    final anchorRect = tester.getRect(
      find.ancestor(
        of: find.byKey(_anchorKey),
        matching: find.byType(CLPressable),
      ),
    );
    final panelRect = tester.getRect(menuPanel());
    if (alignment.x < 0) {
      expect(panelRect.left, closeTo(anchorRect.left, tolerance));
    } else {
      expect(panelRect.right, closeTo(anchorRect.right, tolerance));
    }
    if (alignment.y < 0) {
      expect(panelRect.top, closeTo(anchorRect.top, tolerance));
    } else {
      expect(panelRect.bottom, closeTo(anchorRect.bottom, tolerance));
    }
  }

  Future<void> openMenu(
    WidgetTester tester,
    CLMenuController controller,
  ) async {
    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  test('CLMenu has stable public defaults', () {
    const menu = CLMenu(anchor: SizedBox(), children: [SizedBox()]);

    expect(menu.buttonBuilder, isNull);
    expect(menu.buttonSize, 44);
    expect(menu.menuWidth, 260);
    expect(menu.cornerRadius, isNull);
    expect(menu.padding, const EdgeInsets.all(10));
  });

  testWidgets('supports a CLButton trigger at its actual size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLMenu(
              anchor: const SizedBox.shrink(),
              buttonBuilder: (context, onPressed) => CLButton(
                key: _anchorKey,
                label: '120%',
                width: 75,
                size: CLControlSize.medium,
                variant: CLButtonVariant.secondary,
                trailingIcon: const Icon(Icons.arrow_drop_down),
                onPressed: onPressed,
              ),
              children: const [CLListTile(key: _rowKey, label: '100%')],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(_anchorKey)), const Size(75, 36));
    await tester.tap(find.byKey(_anchorKey));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(CLList), findsOneWidget);
    expect(find.byKey(_rowKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hosts caller content in an internal CLList', (tester) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: const [CLListTile(key: _rowKey, label: 'Custom row')],
      ),
    );

    await openMenu(tester, controller);

    expect(find.byType(CLList), findsOneWidget);
    expect(find.text('Custom row'), findsOneWidget);
    expect(tester.getSize(find.byType(CLList)), const Size(260, 55));
    final listRect = tester.getRect(find.byType(CLList));
    final rowRect = tester.getRect(find.byKey(_rowKey));
    expect(rowRect.left, closeTo(listRect.left + 10, 0.01));
    expect(rowRect.top, closeTo(listRect.top + 10, 0.01));
    expect(rowRect.right, closeTo(listRect.right - 10, 0.01));
    expect(rowRect.bottom, closeTo(listRect.bottom - 10, 0.01));
  });

  testWidgets('keeps target list layout stable through panel morph frames', (
    tester,
  ) async {
    final controller = CLMenuController();
    var layoutCount = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          _LayoutProbe(
            onLayout: () => layoutCount++,
            child: const SizedBox(height: 35),
          ),
        ],
      ),
    );

    controller.open();
    await tester.pump();
    expect(find.byType(CLList), findsOneWidget);
    expect(tester.getSize(find.byType(CLList)).width, 260);

    await tester.pump();
    final visibleLayoutCount = layoutCount;
    final initialPanelWidth = tester.getSize(menuPanel()).width;
    expect(find.byType(CLList), findsOneWidget);
    expect(tester.getSize(find.byType(CLList)).width, 260);

    final morphWidths = <double>[];
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 24));
      morphWidths.add(tester.getSize(menuPanel()).width);
      expect(find.byType(CLList), findsOneWidget);
      expect(tester.getSize(find.byType(CLList)).width, 260);
      expect(layoutCount, visibleLayoutCount);
    }
    expect(morphWidths.any((width) => width != initialPanelWidth), isTrue);

    await tester.pumpAndSettle();
    expect(tester.getSize(menuPanel()).width, closeTo(260, 0.01));
    expect(layoutCount, visibleLayoutCount);
  });

  for (final entry in <String, Alignment>{
    'right and down': Alignment.topLeft,
    'left and down': Alignment.topRight,
    'right and up': Alignment.bottomLeft,
    'left and up': Alignment.bottomRight,
  }.entries) {
    testWidgets('keeps ${entry.key} content anchored throughout morph', (
      tester,
    ) async {
      final controller = CLMenuController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        buildMenu(
          controller: controller,
          alignment: entry.value,
          children: const [CLListTile(key: _rowKey, label: 'Anchored row')],
        ),
      );

      controller.open();
      await tester.pump();
      expect(find.byType(CLList), findsOneWidget);
      expect(tester.getSize(find.byType(CLList)).width, 260);

      await tester.pump();
      expect(find.byType(CLList), findsOneWidget);
      expect(tester.getSize(find.byType(CLList)).width, 260);
      expectAnchoredCorner(tester, entry.value);

      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getSize(menuPanel()).width, isNot(closeTo(260, 0.01)));
      expect(tester.getSize(find.byType(CLList)).width, 260);
      expectAnchoredCorner(tester, entry.value);

      await tester.pumpAndSettle();
      expect(tester.getSize(menuPanel()).width, closeTo(260, 0.01));
      expect(tester.getSize(find.byType(CLList)).width, 260);
      expectAnchoredCorner(tester, entry.value);
      final listRect = tester.getRect(find.byType(CLList));
      final rowRect = tester.getRect(find.byKey(_rowKey));
      expect(rowRect.left, closeTo(listRect.left + 10, 0.01));
      expect(rowRect.right, closeTo(listRect.right - 10, 0.01));
      expect(find.byType(CLList), findsOneWidget);
    });
  }

  testWidgets('partial morph shares paint hit-test and semantics geometry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = CLMenuController();
    var taps = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        alignment: Alignment.topLeft,
        children: [
          Semantics(
            key: _rowKey,
            container: true,
            button: true,
            label: 'Partial row',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(height: 35),
            ),
          ),
        ],
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final paintedRect = tester.getRect(find.byKey(_rowKey));
    final semanticsRect = globalSemanticsRect(
      tester,
      tester.getSemantics(find.byKey(_rowKey)),
    );
    expect(semanticsRect.left, closeTo(paintedRect.left, 0.01));
    expect(semanticsRect.top, closeTo(paintedRect.top, 0.01));
    expect(semanticsRect.right, closeTo(paintedRect.right, 0.01));
    expect(semanticsRect.bottom, closeTo(paintedRect.bottom, 0.01));

    final visibleRect = paintedRect.intersect(tester.getRect(menuPanel()));
    expect(visibleRect.isEmpty, isFalse);
    await tester.tapAt(visibleRect.center);
    await tester.pump();
    expect(taps, 1);
    expect(controller.isOpen, isTrue);
    semantics.dispose();
  });

  testWidgets('keeps child state through the hidden measurement frame', (
    tester,
  ) async {
    final controller = CLMenuController();
    var initCount = 0;
    var disposeCount = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          _LifecycleProbe(
            onInit: () => initCount++,
            onDispose: () => disposeCount++,
          ),
        ],
      ),
    );

    await openMenu(tester, controller);

    expect(initCount, 1);
    expect(disposeCount, 0);
  });

  testWidgets('controller and callback report logical open state', (
    tester,
  ) async {
    final controller = CLMenuController();
    final changes = <bool>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        onOpenChanged: changes.add,
        children: const [CLListTile(label: 'Custom row')],
      ),
    );

    await openMenu(tester, controller);
    expect(controller.isOpen, isTrue);
    expect(changes, [true]);

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(changes, [true, false]);
    expect(find.byType(CLList), findsNothing);
  });

  testWidgets('closing during opening animation restores the anchor', (
    tester,
  ) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: const [CLListTile(label: 'Custom row')],
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    controller.close();
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byType(CLList), findsNothing);

    await tester.tap(find.byKey(_anchorKey));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
  });

  testWidgets('custom row decides when the menu closes', (tester) async {
    final controller = CLMenuController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          CLListTile(
            key: _rowKey,
            label: 'Close menu',
            onTap: controller.close,
          ),
        ],
      ),
    );
    await openMenu(tester, controller);

    await tester.tap(find.byKey(_rowKey));
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byType(CLList), findsNothing);
  });

  testWidgets('panel press glow preserves child gestures', (tester) async {
    final controller = CLMenuController();
    var presses = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          CLListTile(
            key: _rowKey,
            label: 'Keep menu open',
            onTap: () => presses++,
          ),
        ],
      ),
    );
    await openMenu(tester, controller);

    final glow = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_CLMenuPressGlowPainter',
    );
    expect(glow, findsOneWidget);
    final idlePainter = tester.widget<CustomPaint>(glow).painter!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_rowKey)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final pressedPainter = tester.widget<CustomPaint>(glow).painter!;
    expect(pressedPainter.shouldRepaint(idlePainter), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(controller.isOpen, isTrue);
  });

  testWidgets('remeasures dynamic rows once then resizes without relayout', (
    tester,
  ) async {
    final controller = CLMenuController();
    late StateSetter update;
    var rowHeight = 35.0;
    var layoutCount = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return buildMenu(
            controller: controller,
            children: [
              _LayoutProbe(
                onLayout: () => layoutCount++,
                child: SizedBox(height: rowHeight),
              ),
            ],
          );
        },
      ),
    );
    await openMenu(tester, controller);
    expect(tester.getSize(find.byType(CLList)), const Size(260, 55));
    expect(tester.getSize(menuPanel()).height, closeTo(55, 0.01));
    final settledLayoutCount = layoutCount;

    update(() => rowHeight = 105);
    await tester.pump();
    expect(tester.getSize(find.byType(CLList)), const Size(260, 125));
    expect(tester.getSize(menuPanel()).height, closeTo(55, 0.01));
    expect(layoutCount, settledLayoutCount + 1);
    final resizeLayoutCount = layoutCount;

    await tester.pump(const Duration(milliseconds: 90));
    final intermediateHeight = tester.getSize(menuPanel()).height;
    expect(intermediateHeight, greaterThan(55));
    expect(intermediateHeight, lessThan(125));
    expect(tester.getSize(find.byType(CLList)), const Size(260, 125));
    expect(layoutCount, resizeLayoutCount);

    await tester.pumpAndSettle();
    expect(tester.getSize(menuPanel()).height, closeTo(125, 0.01));
    expect(tester.getSize(find.byType(CLList)), const Size(260, 125));
    expect(layoutCount, resizeLayoutCount);
    expect(find.byType(CLList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid close and reopen keeps one preserved continuous list', (
    tester,
  ) async {
    final controller = CLMenuController();
    var initCount = 0;
    var disposeCount = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          _LifecycleProbe(
            onInit: () => initCount++,
            onDispose: () => disposeCount++,
          ),
        ],
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    controller.close();
    await tester.pump(const Duration(milliseconds: 40));
    final closingWidth = tester.getSize(menuPanel()).width;
    expect(closingWidth, greaterThan(44));
    expect(find.byType(CLList), findsOneWidget);

    controller.open();
    await tester.pump();
    expect(find.byType(CLList), findsOneWidget);
    expect(menuPanel(), findsNothing);
    await tester.pump();
    final reopenedWidth = tester.getSize(menuPanel()).width;
    expect(reopenedWidth, closeTo(closingWidth, 0.01));
    expect(reopenedWidth, greaterThan(44));
    expect(find.byType(CLList), findsOneWidget);
    expect(initCount, 1);
    expect(disposeCount, 0);

    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(menuPanel()).width, greaterThan(reopenedWidth));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(find.byType(CLList), findsOneWidget);
    expect(initCount, 1);
    expect(disposeCount, 0);
  });

  testWidgets('reduced fade keeps final geometry and child layout stable', (
    tester,
  ) async {
    final controller = CLMenuController();
    var layoutCount = 0;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        disableAnimations: true,
        children: [
          _LayoutProbe(
            onLayout: () => layoutCount++,
            child: const SizedBox(height: 35),
          ),
        ],
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    final visibleLayoutCount = layoutCount;
    final panelSize = tester.getSize(menuPanel());
    expect(panelSize, const Size(260, 55));
    expect(find.byType(CLList), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 62));
    expect(tester.getSize(menuPanel()), panelSize);
    expect(tester.getSize(find.byType(CLList)), const Size(260, 55));
    expect(layoutCount, visibleLayoutCount);
    await tester.pump(const Duration(milliseconds: 63));
    expect(tester.getSize(menuPanel()), panelSize);
    expect(layoutCount, visibleLayoutCount);
  });

  testWidgets('measurement and logically closed panels are immediately inert', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = CLMenuController();
    final rowFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(rowFocus.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          Semantics(
            label: 'Guarded row',
            button: true,
            child: TextButton(
              key: _rowKey,
              focusNode: rowFocus,
              onPressed: () {},
              child: const Text('Guarded row'),
            ),
          ),
        ],
      ),
    );

    controller.open();
    await tester.pump();
    expect(find.byType(CLList), findsOneWidget);
    expect(find.bySemanticsLabel('Guarded row'), findsNothing);
    expect(rowFocus.hasFocus, isFalse);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 24));
    expect(find.bySemanticsLabel('Guarded row'), findsWidgets);
    expect(rowFocus.hasFocus, isTrue);

    controller.close();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CLList), findsOneWidget);
    expect(
      tester
          .widgetList<ExcludeSemantics>(
            find.ancestor(
              of: find.byKey(_rowKey),
              matching: find.byType(ExcludeSemantics),
            ),
          )
          .map((widget) => widget.excluding),
      contains(true),
    );
    expect(_semanticsTreeHasLabel(tester, 'Guarded row'), isFalse);
    expect(rowFocus.hasFocus, isFalse);

    await tester.pumpAndSettle();
    expect(find.byType(CLList), findsNothing);
    semantics.dispose();
  });

  testWidgets('anchor keyboard activation opens and Escape closes', (
    tester,
  ) async {
    final controller = CLMenuController();
    final rowFocusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(rowFocusNode.dispose);
    await tester.pumpWidget(
      buildMenu(
        controller: controller,
        children: [
          TextButton(
            key: _rowKey,
            focusNode: rowFocusNode,
            onPressed: () {},
            child: const Text('Row'),
          ),
        ],
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final anchorFocus = FocusManager.instance.primaryFocus;
    expect(anchorFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(controller.isOpen, isTrue);
    expect(rowFocusNode.hasFocus, isTrue);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 24));
      expect(rowFocusNode.hasFocus, isTrue);
      expect(find.byType(CLList), findsOneWidget);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byType(CLList), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(anchorFocus));
  });
}

bool _semanticsTreeHasLabel(WidgetTester tester, String label) {
  final root =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;
  var found = false;

  void visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) found = true;
    node.visitChildren((child) {
      visit(child);
      return !found;
    });
  }

  visit(root);
  return found;
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLayoutProbe renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
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
