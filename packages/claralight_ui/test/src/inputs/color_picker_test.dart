import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
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

  testWidgets('CLColorPicker selects preset swatches', (
    WidgetTester tester,
  ) async {
    Color? picked;
    const preset = Color(0xFF297E7B);

    await tester.pumpWidget(
      host(
        CLColorPicker(
          color: const Color(0xFFFF0000),
          swatches: const [preset, Color(0xFF3F80A6)],
          onChanged: (c) => picked = c,
        ),
      ),
    );

    await tester.tap(find.byType(CLColorSwatchItem).first);
    await tester.pumpAndSettle();

    expect(picked?.toARGB32(), preset.toARGB32());
  });
}
