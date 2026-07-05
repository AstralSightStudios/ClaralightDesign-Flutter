import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
    testWidgets('Glass renders its child', (WidgetTester tester) async {
        const key = Key('glass-child');
        await tester.pumpWidget(
            MaterialApp(
                home: Scaffold(
                    body: Glass(
                        child: Container(key: key),
                    ),
                ),
            ),
        );

        expect(find.byType(Glass), findsOneWidget);
        expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('CLIconButton reports taps', (WidgetTester tester) async {
        var tapped = false;
        await tester.pumpWidget(
            MaterialApp(
                home: Scaffold(
                    body: CLIconButton(
                        icon: Icons.add,
                        onPressed: () => tapped = true,
                    ),
                ),
            ),
        );

        await tester.tap(find.byType(CLIconButton));
        expect(tapped, isTrue);
    });
}
