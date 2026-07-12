import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _toolbarKey = Key('toolbar');
const _toolbarChildKey = Key('toolbar-child');

Widget host(CLColorScheme colors) {
  return CLTheme(
    data: CLThemeData(colors: colors),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: CLToolbar(
          key: _toolbarKey,
          children: [SizedBox.square(key: _toolbarChildKey, dimension: 36)],
        ),
      ),
    ),
  );
}

void main() {
  for (final colors in [
    const CLColorScheme.light(),
    const CLColorScheme.dark(),
  ]) {
    testWidgets(
      'frosted ${colors.brightness.name} surfaces paint shadows after blur',
      (WidgetTester tester) async {
        await tester.pumpWidget(host(colors));

        final backdrop = find.byType(BackdropFilter);
        expect(backdrop, findsOneWidget);
        expect(
          find.ancestor(
            of: backdrop,
            matching: find.byWidgetPredicate((widget) {
              final decoration = widget is Container ? widget.decoration : null;
              return decoration is ShapeDecoration &&
                  decoration.shadows?.isNotEmpty == true;
            }),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(CLSurface),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'frosted ${colors.brightness.name} surface preserves tight constraints',
      (WidgetTester tester) async {
        await tester.pumpWidget(host(colors));

        final toolbarRect = tester.getRect(find.byKey(_toolbarKey));
        final childRect = tester.getRect(find.byKey(_toolbarChildKey));

        expect(toolbarRect.height, 44);
        expect(childRect.height, 36);
        expect(childRect.top - toolbarRect.top, 4);
        expect(toolbarRect.bottom - childRect.bottom, 4);
      },
    );
  }
}
