import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui_gallery/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Gallery shows the Claralight component sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    expect(find.text('Claralight UI'), findsOneWidget);
    expect(find.text('CLButton'), findsOneWidget);
    expect(find.text('CLToggle'), findsOneWidget);
    expect(find.text('CLSegmentedControl'), findsOneWidget);
    expect(find.text('CLDialog'), findsOneWidget);
    expect(find.text('CLMenu'), findsOneWidget);
    expect(find.byType(CLButton), findsWidgets);
    expect(find.byType(CLToggle), findsWidgets);
    expect(find.byType(CLSegmentedControl), findsWidgets);
    expect(find.byType(CLColorSwatchGroup), findsWidgets);
    expect(find.byType(CLProgressBar), findsWidgets);
    expect(find.byType(CLMenu), findsWidgets);
  });
}
