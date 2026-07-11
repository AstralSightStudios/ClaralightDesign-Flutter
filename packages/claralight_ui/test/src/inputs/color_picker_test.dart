import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    );
  }

  testWidgets('CLColorPicker reports picks from the SV area', (
    WidgetTester tester,
  ) async {
    Color? picked;

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          onChanged: (c) => picked = c,
        ),
      ),
    );

    // Drag to the top-right corner of the SV area: full saturation and
    // value of the current hue — pure red.
    final area = find.byKey(const Key('cl-color-picker-sv'));
    await tester.tapAt(tester.getTopRight(area) + const Offset(-1, 1));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    final argb = picked!.toARGB32();
    // One pixel in from the corner: effectively pure red.
    expect((argb >> 16) & 0xFF, greaterThan(0xF0));
    expect((argb >> 8) & 0xFF, lessThan(0x10));
    expect(argb & 0xFF, lessThan(0x10));
  });

  testWidgets('CLColorPicker ignores trackpad scrolling over pick areas', (
    WidgetTester tester,
  ) async {
    var changeCount = 0;

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          onChanged: (_) => changeCount++,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('cl-color-picker-sv')),
      const Offset(60, 60),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.drag(
      find.byKey(const Key('cl-color-picker-hue')),
      const Offset(60, 0),
      kind: PointerDeviceKind.trackpad,
    );
    await tester.pump();

    expect(changeCount, 0);
  });

  testWidgets('CLColorPicker hex field applies submitted values', (
    WidgetTester tester,
  ) async {
    Color? picked;

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          onChanged: (c) => picked = c,
        ),
      ),
    );

    await tester.enterText(find.byType(CLTextField), '00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.toARGB32() & 0xFFFFFF, 0x00FF00);
  });

  testWidgets('CLColorPicker clears a hex error after picking a color', (
    WidgetTester tester,
  ) async {
    Color? picked;

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          onChanged: (c) => picked = c,
        ),
      ),
    );

    final field = find.byType(CupertinoTextField);
    await tester.tap(field);
    await tester.enterText(field, 'invalid');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(
      tester.widget<CupertinoTextField>(field).style?.color,
      CLThemeData().colors.danger,
    );

    final area = find.byKey(const Key('cl-color-picker-sv'));
    await tester.tapAt(tester.getTopRight(area) + const Offset(-1, 1));
    await tester.pumpAndSettle();

    final textField = tester.widget<CupertinoTextField>(field);
    expect(textField.style?.color, isNot(CLThemeData().colors.danger));
    expect(textField.controller?.text, isNot('invalid'));
    expect(picked, isNotNull);
  });

  testWidgets('CLColorPicker retains and marks an invalid hex value', (
    WidgetTester tester,
  ) async {
    Color? picked;

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          onChanged: (c) => picked = c,
        ),
      ),
    );

    final field = find.byType(CupertinoTextField);
    await tester.tap(field);
    await tester.enterText(field, 'invalid');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    CupertinoTextField textField() => tester.widget<CupertinoTextField>(field);

    expect(textField().controller?.text, 'invalid');
    expect(textField().style?.color, CLThemeData().colors.danger);
    expect(picked, isNull);

    await tester.tap(field);
    await tester.enterText(field, '00FF00');
    await tester.pumpAndSettle();

    expect(textField().style?.color, isNot(CLThemeData().colors.danger));
    expect(picked?.toARGB32(), const Color(0xFF00FF00).toARGB32());
  });
}
