import 'package:claralight_ui/claralight_ui.dart';
import 'package:claralight_ui_gallery/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Gallery shows CLButton examples', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == galleryBackgroundImageUrl,
      ),
      findsOneWidget,
    );
    expect(find.text('CLButton'), findsOneWidget);
    expect(find.text('Primary with both icons'), findsOneWidget);
    expect(find.text('Neutral with leading icon'), findsOneWidget);
    expect(find.text('Danger without icons'), findsOneWidget);
    expect(find.byType(CLButton), findsNWidgets(4));
  });
}
