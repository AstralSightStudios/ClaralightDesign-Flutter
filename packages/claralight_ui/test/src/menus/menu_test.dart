import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
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
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CLMenu(
            controller: controller,
            onOpenChanged: onOpenChanged,
            anchor: const Icon(Icons.more_horiz, key: _anchorKey),
            children: children,
          ),
        ),
      ),
    );
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

    expect(menu.buttonSize, 44);
    expect(menu.menuWidth, 260);
    expect(menu.cornerRadius, isNull);
    expect(menu.padding, const EdgeInsets.all(10));
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
    expect(rowRect.right, closeTo(listRect.right - 10, 0.01));
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

  testWidgets('remeasures changing children while open', (tester) async {
    final controller = CLMenuController();
    late StateSetter update;
    var count = 1;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return buildMenu(
            controller: controller,
            children: [
              for (var index = 0; index < count; index++)
                CLListTile(label: 'Row $index'),
            ],
          );
        },
      ),
    );
    await openMenu(tester, controller);
    expect(tester.getSize(find.byType(CLList)).height, 55);

    update(() => count = 3);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(CLList)).height, 125);
    expect(tester.takeException(), isNull);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.isOpen, isTrue);
    expect(rowFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byType(CLList), findsNothing);
  });
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
