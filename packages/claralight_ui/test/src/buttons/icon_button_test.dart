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

  BorderSide outlineSide(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(CLIconButton),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground,
        ),
      ),
    );
    final shape = (box.decoration as ShapeDecoration).shape;
    return (shape as RoundedSuperellipseBorder).side;
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

    for (final (size, extent, iconSize) in [
      (CLControlSize.small, 28.0, 16.0),
      (CLControlSize.medium, 36.0, 19.0),
      (CLControlSize.large, 44.0, 22.0),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, size: size, onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(CLSurface)),
        Size.square(extent),
        reason: 'extent of $size',
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.add)).size,
        iconSize,
        reason: 'icon size of $size',
      );
    }
  });

  testWidgets('CLIconButton supports the exact Figma floating and bare sizes', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    await tester.pumpWidget(
      host(
        CLIconButton(
          icon: Icons.title_rounded,
          size: CLControlSize.medium,
          variant: CLIconButtonVariant.floating,
          onPressed: () {},
        ),
      ),
    );

    var surface = tester.widget<CLSurface>(find.byType(CLSurface));
    var icon = tester.widget<Icon>(find.byIcon(Icons.title_rounded));
    expect(tester.getSize(find.byType(CLSurface)), const Size.square(36));
    expect(surface.fill, theme.colors.floatingControl);
    expect(surface.frosted, isTrue);
    expect(surface.frostSigma, 10);
    expect(surface.shadow, const [
      BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 10),
    ]);
    expect(icon.size, 18);
    expect(icon.color, theme.colors.onFloatingControl);
    expect(outlineSide(tester), BorderSide(color: theme.colors.outline));

    final lightTheme = CLThemeData(colors: const CLColorScheme.light());
    await tester.pumpWidget(
      CLTheme(
        data: lightTheme,
        child: host(
          CLIconButton(
            icon: Icons.title_rounded,
            extent: 32,
            iconSize: 18,
            variant: CLIconButtonVariant.ghost,
            iconColor: lightTheme.colors.textPrimary,
            onPressed: () {},
          ),
        ),
      ),
    );

    surface = tester.widget<CLSurface>(find.byType(CLSurface));
    icon = tester.widget<Icon>(find.byIcon(Icons.title_rounded));
    expect(tester.getSize(find.byType(CLSurface)), const Size.square(32));
    expect(surface.fill, const Color(0x00000000));
    expect(surface.frosted, isFalse);
    expect(surface.shadow, isNull);
    expect(icon.size, 18);
    expect(icon.color, const Color(0xFF160A01));
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
      (
        CLIconButtonVariant.floating,
        theme.colors.floatingControl,
        theme.colors.onFloatingControl,
      ),
      (CLIconButtonVariant.danger, theme.colors.danger, theme.colors.onDanger),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, variant: variant, onPressed: () {})),
      );

      expect(tester.widget<CLSurface>(find.byType(CLSurface)).fill, fill);
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, foreground);
    }
  });

  testWidgets('CLIconButton outlines non-ghost variants by default', (
    WidgetTester tester,
  ) async {
    final outline = CLThemeData().colors.outline;

    for (final (variant, expectedOutlined) in [
      (CLIconButtonVariant.primary, true),
      (CLIconButtonVariant.secondary, true),
      (CLIconButtonVariant.danger, true),
      (CLIconButtonVariant.ghost, false),
      (CLIconButtonVariant.floating, true),
    ]) {
      await tester.pumpWidget(
        host(CLIconButton(icon: Icons.add, variant: variant, onPressed: () {})),
      );

      expect(
        outlineSide(tester),
        expectedOutlined ? BorderSide(color: outline) : BorderSide.none,
        reason: 'outline of $variant',
      );
    }
  });

  testWidgets('CLIconButton outline can be enabled, disabled, and recolored', (
    WidgetTester tester,
  ) async {
    const customOutline = Color(0xFF00FF00);

    await tester.pumpWidget(
      host(
        CLIconButton(
          icon: Icons.add,
          variant: CLIconButtonVariant.ghost,
          outlined: true,
          outlineColor: customOutline,
          onPressed: () {},
        ),
      ),
    );
    expect(outlineSide(tester), const BorderSide(color: customOutline));

    await tester.pumpWidget(
      host(CLIconButton(icon: Icons.add, outlined: false, onPressed: () {})),
    );
    expect(outlineSide(tester), BorderSide.none);
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
      (CLIconButtonVariant.floating, theme.colors.floatingControl),
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

  testWidgets('CLIconButton disabled floating keeps its glass layer', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();
    await tester.pumpWidget(
      host(
        const CLIconButton(
          icon: Icons.add,
          variant: CLIconButtonVariant.floating,
          onPressed: null,
        ),
      ),
    );

    final surface = tester.widget<CLSurface>(find.byType(CLSurface));
    expect(surface.fill, theme.colors.floatingControl);
    expect(surface.shadow, isNotNull);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      theme.colors.textDisabled,
    );
  });
}
