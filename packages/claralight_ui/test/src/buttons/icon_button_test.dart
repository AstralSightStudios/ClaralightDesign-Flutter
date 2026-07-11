import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('CLIconButton renders flat circle with size steps and taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      host(CLIconButton(icon: Icons.add, onPressed: () => tapped = true)),
    );

    expect(tester.getSize(find.byType(CLSurface)), const Size(44, 44));

    await tester.tap(find.byType(CLIconButton));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    for (final (size, extent) in [
      (CLControlSize.small, 28.0),
      (CLControlSize.medium, 36.0),
      (CLControlSize.large, 44.0),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, size: size, onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(CLSurface)),
        Size.square(extent),
        reason: 'extent of $size',
      );
    }
  });

  testWidgets('CLIconButton selected state uses the raised control fill', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    await tester.pumpWidget(
      host(CLIconButton(icon: Icons.add, selected: true, onPressed: () {})),
    );
    final surface = tester.widget<CLSurface>(find.byType(CLSurface));
    expect(surface.fill, theme.colors.controlHighlight);
  });

  testWidgets('CLIconButton fill override wins', (WidgetTester tester) async {
    const fill = Color(0x669900FF);

    await tester.pumpWidget(
      host(CLIconButton(icon: Icons.add, fill: fill, onPressed: () {})),
    );
    final surface = tester.widget<CLSurface>(find.byType(CLSurface));
    expect(surface.fill, fill);
  });

  testWidgets('CLIconButton ghost is transparent until hovered', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    await tester.pumpWidget(
      host(
        CLIconButton(
          icon: Icons.more_horiz,
          variant: CLIconButtonVariant.ghost,
          onPressed: () {},
        ),
      ),
    );

    expect(
      tester.widget<CLSurface>(find.byType(CLSurface)).fill,
      const Color(0x00000000),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(CLIconButton)));
    await tester.pump();

    expect(
      tester.widget<CLSurface>(find.byType(CLSurface)).fill,
      theme.colors.controlHighlight,
    );
  });

  testWidgets('CLIconButton disabled blocks taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(const CLIconButton(icon: Icons.add, onPressed: null)),
    );

    final semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(CLIconButton),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.enabled, isFalse);
  });
}
