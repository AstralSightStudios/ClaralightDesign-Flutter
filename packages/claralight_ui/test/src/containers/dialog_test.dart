import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget hostWithActions(int actionCount) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CLDialog(
            maxWidth: 400,
            actions: [
              for (var i = 0; i < actionCount; i++)
                SizedBox(key: Key('action-$i'), height: 44),
            ],
            child: const SizedBox(width: 200, height: 40),
          ),
        ),
      ),
    );
  }

  Rect actionRect(WidgetTester tester, int index) {
    return tester.getRect(find.byKey(Key('action-$index')));
  }

  testWidgets('lays out two actions horizontally with equal widths', (
    tester,
  ) async {
    await tester.pumpWidget(hostWithActions(2));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);

    expect(first.center.dy, second.center.dy);
    expect(second.left - first.right, 10);
    expect(first.width, second.width);
  });

  testWidgets('stacks three actions vertically at full width', (tester) async {
    await tester.pumpWidget(hostWithActions(3));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);
    final third = actionRect(tester, 2);

    expect(first.center.dx, second.center.dx);
    expect(second.center.dx, third.center.dx);
    expect(second.top - first.bottom, 10);
    expect(third.top - second.bottom, 10);
    expect(first.width, second.width);
    expect(second.width, third.width);
  });
}
