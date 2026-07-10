import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLChipTabs renders all tabs and reports taps', (
    WidgetTester tester,
  ) async {
    int? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CLChipTabs(
              tabs: const ['时间日期', '运动健康', '工具数据'],
              selectedIndex: 0,
              onChanged: (i) => tapped = i,
            ),
          ),
        ),
      ),
    );

    expect(find.text('时间日期'), findsOneWidget);
    expect(find.text('运动健康'), findsOneWidget);
    expect(find.text('工具数据'), findsOneWidget);

    await tester.tap(find.text('运动健康'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
