import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  testWidgets('CLIconButton uses InteractiveGlass and reports taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CLIconButton(icon: Icons.add, onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.byType(InteractiveGlass), findsOneWidget);
    expect(
      tester.widget<InteractiveGlass>(find.byType(InteractiveGlass)).size,
      44,
    );

    await tester.tap(find.byType(CLIconButton));
    expect(tapped, isTrue);
  });
}
