import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  test('CLIconButton exposes large as its default configured size', () {
    expect(
      const CLIconButton(icon: Icons.add, onPressed: null).size,
      CLControlSize.large,
    );
  });

  testWidgets('CLIconButton renders frosted circle with size steps and taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      host(CLIconButton(icon: Icons.add, onPressed: () => tapped = true)),
    );

    expect(tester.getSize(find.byType(CLSurface)), const Size(44, 44));
    expect(tester.widget<CLSurface>(find.byType(CLSurface)).frosted, isTrue);

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

  testWidgets('CLIconButton semantic variants use scheme colors', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    for (final (variant, fill, foreground) in [
      (CLIconButtonVariant.primary, theme.colors.accent, theme.colors.onAccent),
      (CLIconButtonVariant.danger, theme.colors.danger, theme.colors.onDanger),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, variant: variant, onPressed: () {})),
      );

      expect(tester.widget<CLSurface>(find.byType(CLSurface)).fill, fill);
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, foreground);
    }
  });

  testWidgets('CLIconButton semantic variants lighten on hover', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    for (final (variant, fill) in [
      (CLIconButtonVariant.primary, theme.colors.accent),
      (CLIconButtonVariant.danger, theme.colors.danger),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, variant: variant, onPressed: () {})),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byType(CLIconButton)));
      await tester.pump();

      expect(
        tester.widget<CLSurface>(find.byType(CLSurface)).fill,
        Color.lerp(fill, const Color(0xFFFFFFFF), 0.08),
      );
    }
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
    expect(tester.widget<CLSurface>(find.byType(CLSurface)).frosted, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(CLIconButton)));
    await tester.pump();

    expect(
      tester.widget<CLSurface>(find.byType(CLSurface)).fill,
      theme.colors.controlHighlight,
    );
    expect(tester.widget<CLSurface>(find.byType(CLSurface)).frosted, isFalse);
  });

  testWidgets('CLIconButton disabled blocks taps and drops semantic color', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    for (final variant in [
      CLIconButtonVariant.primary,
      CLIconButtonVariant.danger,
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, variant: variant, onPressed: null)),
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
      expect(
        tester.widget<CLSurface>(find.byType(CLSurface)).fill,
        theme.colors.control,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.add)).color,
        theme.colors.textDisabled,
      );
    }
  });
}
