import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui_gallery/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(CLScrollable.precache);

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
    expect(find.byType(CLTreeView), findsOneWidget);

    final subtreeLeaf = tester.widget<CLListTile>(
      find.widgetWithText(CLListTile, '矩形 1'),
    );
    expect(subtreeLeaf.depth, 2);
  });

  testWidgets('Gallery exposes the interactive CLScrollable demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();

    expect(find.text('CLScrollable'), findsOneWidget);
    expect(find.text('双轴'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    final demo = tester.widget<CLScrollable>(
      find.byKey(const Key('scrollable-demo')),
    );
    expect(demo.direction, CLScrollDirection.both);
    expect(demo.horizontalScrollbar, CLScrollbarVisibility.auto);
    expect(demo.verticalScrollbar, CLScrollbarVisibility.auto);

    await tester.ensureVisible(find.text('横向'));
    await tester.tap(find.text('横向'));
    await tester.pump();
    await tester.tap(find.text('始终'));
    await tester.pump();

    final updatedDemo = tester.widget<CLScrollable>(
      find.byKey(const Key('scrollable-demo')),
    );
    expect(updatedDemo.direction, CLScrollDirection.horizontal);
    expect(updatedDemo.horizontalScrollbar, CLScrollbarVisibility.always);
    expect(updatedDemo.verticalScrollbar, CLScrollbarVisibility.always);
  });
}
