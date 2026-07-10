import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLTooltip shows its message on long press', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLTooltip(
              message: '这按钮是干嘛的',
              child: CLIconButton(icon: Icons.help, onPressed: () {}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('这按钮是干嘛的'), findsNothing);

    await tester.longPress(find.byType(CLIconButton));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('这按钮是干嘛的'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
