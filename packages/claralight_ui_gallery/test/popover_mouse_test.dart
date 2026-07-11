import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui_gallery/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery popover opens from a mouse click without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    final popover = find.byType(CLPopover);
    expect(popover, findsOneWidget);
    await tester.ensureVisible(popover);
    await tester.pump(const Duration(milliseconds: 500));

    final anchor = find.descendant(
      of: popover,
      matching: find.byType(CLButton),
    );
    expect(anchor, findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(anchor));
    await tester.pump();
    await mouse.down(tester.getCenter(anchor));
    await tester.pump();
    await mouse.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
  });
}
