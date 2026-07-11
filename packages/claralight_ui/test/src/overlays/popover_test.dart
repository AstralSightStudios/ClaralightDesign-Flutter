import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _anchorKey = Key('anchor');
const _contentKey = Key('content');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildPopover({
    required CLPopoverController controller,
    CLPopoverPosition position = CLPopoverPosition.top,
    bool showArrow = true,
    Alignment anchorAlignment = Alignment.center,
    Size contentSize = const Size(120, 60),
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    ValueChanged<bool>? onOpenChanged,
    VoidCallback? onAnchorPressed,
  }) {
    return MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            viewPadding: viewPadding,
            viewInsets: viewInsets,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: Align(
          alignment: anchorAlignment,
          child: CLPopover(
            controller: controller,
            position: position,
            showArrow: showArrow,
            onOpenChanged: onOpenChanged,
            anchorBuilder: (context, popover) => TextButton(
              key: _anchorKey,
              onPressed: onAnchorPressed ?? popover.toggle,
              child: const Text('Anchor'),
            ),
            popoverBuilder: (context, popover) => SizedBox(
              key: _contentKey,
              width: contentSize.width,
              height: contentSize.height,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openPopover(
    WidgetTester tester,
    CLPopoverController controller,
  ) async {
    controller.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final position in CLPopoverPosition.values) {
    testWidgets('places content on the preferred ${position.name} side', (
      tester,
    ) async {
      final controller = CLPopoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        buildPopover(controller: controller, position: position),
      );
      await openPopover(tester, controller);

      final anchor = tester.getRect(find.byKey(_anchorKey));
      final content = tester.getRect(find.byKey(_contentKey));
      switch (position) {
        case CLPopoverPosition.top:
          expect(content.bottom, lessThan(anchor.top));
        case CLPopoverPosition.bottom:
          expect(content.top, greaterThan(anchor.bottom));
        case CLPopoverPosition.left:
          expect(content.right, lessThan(anchor.left));
        case CLPopoverPosition.right:
          expect(content.left, greaterThan(anchor.right));
      }
    });
  }

  testWidgets(
    'flips to the opposite side when preferred space is insufficient',
    (tester) async {
      final controller = CLPopoverController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        buildPopover(
          controller: controller,
          position: CLPopoverPosition.top,
          anchorAlignment: Alignment.topCenter,
          contentSize: const Size(120, 80),
        ),
      );
      await openPopover(tester, controller);

      final anchor = tester.getRect(find.byKey(_anchorKey));
      final content = tester.getRect(find.byKey(_contentKey));
      expect(content.top, greaterThan(anchor.bottom));
    },
  );

  testWidgets('clamps oversized content to safe area and keyboard insets', (
    tester,
  ) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildPopover(
        controller: controller,
        position: CLPopoverPosition.bottom,
        contentSize: const Size(1000, 1000),
        viewPadding: const EdgeInsets.only(top: 24),
        viewInsets: const EdgeInsets.only(bottom: 120),
      ),
    );
    await openPopover(tester, controller);

    final content = tester.getRect(find.byKey(_contentKey));
    expect(content.left, greaterThanOrEqualTo(8));
    expect(content.top, greaterThanOrEqualTo(32));
    expect(content.right, lessThanOrEqualTo(792));
    expect(content.bottom, lessThanOrEqualTo(472));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-axis shifting keeps content inside the screen margin', (
    tester,
  ) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildPopover(
        controller: controller,
        position: CLPopoverPosition.bottom,
        anchorAlignment: Alignment.topLeft,
        contentSize: const Size(260, 60),
      ),
    );
    await openPopover(tester, controller);

    final content = tester.getRect(find.byKey(_contentKey));
    expect(content.left, greaterThanOrEqualTo(8));
  });

  testWidgets('showArrow does not move the popover body', (tester) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildPopover(controller: controller, showArrow: true),
    );
    await openPopover(tester, controller);
    final withArrow = tester.getRect(find.byKey(_contentKey));

    controller.close();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      buildPopover(controller: controller, showArrow: false),
    );
    await openPopover(tester, controller);
    final withoutArrow = tester.getRect(find.byKey(_contentKey));

    expect(withoutArrow.topLeft, withArrow.topLeft);
  });

  testWidgets('controller and callback report logical open state', (
    tester,
  ) async {
    final controller = CLPopoverController();
    final changes = <bool>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildPopover(controller: controller, onOpenChanged: changes.add),
    );

    controller.open();
    await tester.pump();
    await tester.pump();
    expect(controller.isOpen, isTrue);
    expect(changes, [true]);
    expect(find.byKey(_contentKey), findsOneWidget);

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(changes, [true, false]);
    expect(find.byKey(_contentKey), findsNothing);
  });

  testWidgets('onOpenChanged can synchronously reverse the state', (
    tester,
  ) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildPopover(
        controller: controller,
        onOpenChanged: (open) {
          if (open) controller.close();
        },
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byKey(_contentKey), findsNothing);
  });

  testWidgets('supports content that cannot compute dry layout', (
    tester,
  ) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLPopover(
              controller: controller,
              anchorBuilder: (context, popover) => TextButton(
                onPressed: popover.toggle,
                child: const Text('Anchor'),
              ),
              popoverBuilder: (context, popover) => LayoutBuilder(
                builder: (context, constraints) =>
                    const SizedBox(key: _contentKey, width: 180, height: 80),
              ),
            ),
          ),
        ),
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_contentKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening with a mouse does not re-enter mouse tracking', (
    tester,
  ) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLPopover(
              controller: controller,
              anchorBuilder: (context, popover) => CLButton(
                key: _anchorKey,
                label: 'Open',
                onPressed: popover.toggle,
              ),
              popoverBuilder: (context, popover) =>
                  const SizedBox(key: _contentKey, width: 240, height: 120),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(_anchorKey)));
    await tester.pump();
    await mouse.down(tester.getCenter(find.byKey(_anchorKey)));
    await tester.pump();
    await mouse.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.isOpen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background remains scrollable while the popover is open', (
    tester,
  ) async {
    final controller = CLPopoverController();
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: 1200,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: CLPopover(
                    controller: controller,
                    anchorBuilder: (context, popover) => TextButton(
                      onPressed: popover.toggle,
                      child: const Text('Anchor'),
                    ),
                    popoverBuilder: (context, popover) =>
                        const SizedBox(width: 120, height: 60),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await openPopover(tester, controller);

    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(20, 500),
        scrollDelta: Offset(0, 80),
      ),
    );
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));
    expect(controller.isOpen, isTrue);

    scrollController.jumpTo(0);
    controller.open();
    await tester.pump();
    await tester.dragFrom(const Offset(20, 500), const Offset(0, -100));
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets('outside click closes without blocking the underlying action', (
    tester,
  ) async {
    final controller = CLPopoverController();
    var outsidePresses = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                top: 20,
                child: TextButton(
                  key: const Key('outside'),
                  onPressed: () => outsidePresses++,
                  child: const Text('Outside'),
                ),
              ),
              Center(
                child: CLPopover(
                  controller: controller,
                  anchorBuilder: (context, popover) => TextButton(
                    onPressed: popover.toggle,
                    child: const Text('Anchor'),
                  ),
                  popoverBuilder: (context, popover) =>
                      const SizedBox(width: 120, height: 60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await openPopover(tester, controller);

    await tester.tap(find.byKey(const Key('outside')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(outsidePresses, 1);

    await tester.tap(find.byKey(const Key('outside')));
    expect(outsidePresses, 2);
  });

  testWidgets('Escape closes the popover', (tester) async {
    final controller = CLPopoverController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildPopover(controller: controller));
    await openPopover(tester, controller);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byKey(_contentKey), findsNothing);
  });

  testWidgets('focus enters the popover and returns to the anchor', (
    tester,
  ) async {
    final controller = CLPopoverController();
    final anchorFocus = FocusNode();
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(anchorFocus.dispose);
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLPopover(
              controller: controller,
              anchorBuilder: (context, popover) => TextButton(
                focusNode: anchorFocus,
                onPressed: popover.toggle,
                child: const Text('Anchor'),
              ),
              popoverBuilder: (context, popover) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(focusNode: firstFocus),
                  TextField(focusNode: secondFocus),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    anchorFocus.requestFocus();
    await tester.pump();
    expect(anchorFocus.hasFocus, isTrue);

    await openPopover(tester, controller);
    expect(firstFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    controller.close();
    await tester.pumpAndSettle();
    expect(anchorFocus.hasFocus, isTrue);
  });

  testWidgets('an off-screen anchor keeps its popover pinned and open', (
    tester,
  ) async {
    final controller = CLPopoverController();
    final translation = ValueNotifier(Offset.zero);
    addTearDown(controller.dispose);
    addTearDown(translation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Offset>(
            valueListenable: translation,
            builder: (context, offset, child) => Transform.translate(
              offset: offset,
              child: Center(
                child: CLPopover(
                  controller: controller,
                  position: CLPopoverPosition.top,
                  anchorBuilder: (context, popover) => TextButton(
                    onPressed: popover.toggle,
                    child: const Text('Anchor'),
                  ),
                  popoverBuilder: (context, popover) =>
                      const SizedBox(key: _contentKey, width: 120, height: 60),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await openPopover(tester, controller);

    translation.value = const Offset(0, -600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final content = tester.getRect(find.byKey(_contentKey));
    expect(controller.isOpen, isTrue);
    expect(content.top, greaterThanOrEqualTo(8));
    expect(content.bottom, lessThanOrEqualTo(592));
  });
}
