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
        of: find.byType(CLButton),
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

  test('CLButton exposes large as its default configured size', () {
    expect(const CLButton(label: 'Continue').size, CLControlSize.large);
  });

  testWidgets('CLButton renders the flat Claralight base', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(CLButton(label: '继续', onPressed: () {})));

    expect(find.byType(CLSurface), findsOneWidget);
    expect(tester.widget<CLSurface>(find.byType(CLSurface)).frosted, isTrue);

    final box = tester.getSize(find.byType(CLSurface));
    expect(box.height, 50);
  });

  testWidgets('CLButton sizes follow the density steps', (
    WidgetTester tester,
  ) async {
    for (final (size, height) in [
      (CLControlSize.small, 28.0),
      (CLControlSize.medium, 36.0),
      (CLControlSize.large, 50.0),
    ]) {
      await tester.pumpWidget(
        host(CLButton(label: '继续', size: size, onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(CLSurface)).height,
        height,
        reason: 'height of $size',
      );
    }
  });

  testWidgets('CLButton hugs content by default and accepts fixed width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(CLButton(label: '继续', onPressed: () {})));
    final hugged = tester.getSize(find.byType(CLSurface)).width;

    await tester.pumpWidget(
      host(CLButton(label: '继续', width: 300, onPressed: () {})),
    );
    final fixed = tester.getSize(find.byType(CLSurface)).width;

    expect(hugged, lessThan(300));
    expect(fixed, 300);
  });

  testWidgets('CLButton centers a full-width label independently of icons', (
    WidgetTester tester,
  ) async {
    const leadingKey = Key('leading-icon');
    const trailingKey = Key('trailing-icon');

    Future<void> expectLayout({
      required bool constrainedByParent,
      Widget? leadingIcon,
      Widget? trailingIcon,
    }) async {
      final button = CLButton(
        width: constrainedByParent ? null : 354,
        label: '继续',
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon,
        onPressed: () {},
      );
      await tester.pumpWidget(
        host(
          constrainedByParent
              ? SizedBox(
                  width: 354,
                  child: Row(children: [Expanded(child: button)]),
                )
              : button,
        ),
      );

      final buttonRect = tester.getRect(find.byType(CLSurface));
      final textRect = tester.getRect(find.text('继续'));
      expect(textRect.center.dx, moreOrLessEquals(buttonRect.center.dx));
    }

    await expectLayout(
      constrainedByParent: false,
      leadingIcon: const SizedBox(key: leadingKey, width: 24, height: 24),
    );
    final leadingRect = tester.getRect(find.byKey(leadingKey));
    final leadingButtonRect = tester.getRect(find.byType(CLSurface));
    expect(leadingRect.left, leadingButtonRect.left + 16);

    await expectLayout(
      constrainedByParent: false,
      trailingIcon: const SizedBox(key: trailingKey, width: 24, height: 24),
    );
    final trailingRect = tester.getRect(find.byKey(trailingKey));
    final trailingButtonRect = tester.getRect(find.byType(CLSurface));
    expect(trailingRect.right, trailingButtonRect.right - 16);

    // ExportPage uses Expanded rather than CLButton.width; the label must
    // still stay centered when only the trailing arrow is present.
    await expectLayout(
      constrainedByParent: true,
      trailingIcon: const SizedBox(width: 24, height: 24),
    );
  });

  testWidgets('CLButton reports taps', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      host(CLButton(label: '继续', onPressed: () => tapped = true)),
    );

    await tester.tap(find.byType(CLButton));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('CLButton variants use the scheme fills', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    Future<Color> fillFor(CLButtonVariant variant) async {
      await tester.pumpWidget(
        host(CLButton(label: '继续', variant: variant, onPressed: () {})),
      );
      final surface = tester.widget<CLSurface>(find.byType(CLSurface));
      return surface.fill!;
    }

    expect(await fillFor(CLButtonVariant.primary), theme.colors.accent);
    expect(await fillFor(CLButtonVariant.secondary), theme.colors.control);
    expect(await fillFor(CLButtonVariant.danger), theme.colors.danger);
  });

  testWidgets('CLButton outlines non-ghost variants by default', (
    WidgetTester tester,
  ) async {
    final outline = CLThemeData().colors.outline;

    for (final (variant, expectedOutlined) in [
      (CLButtonVariant.primary, true),
      (CLButtonVariant.secondary, true),
      (CLButtonVariant.danger, true),
      (CLButtonVariant.ghost, false),
    ]) {
      await tester.pumpWidget(
        host(CLButton(label: '继续', variant: variant, onPressed: () {})),
      );

      expect(
        outlineSide(tester),
        expectedOutlined ? BorderSide(color: outline) : BorderSide.none,
        reason: 'outline of $variant',
      );
    }
  });

  testWidgets('CLButton outline can be enabled, disabled, and recolored', (
    WidgetTester tester,
  ) async {
    const customOutline = Color(0xFF00FF00);

    await tester.pumpWidget(
      host(
        CLButton(
          label: '继续',
          variant: CLButtonVariant.ghost,
          outlined: true,
          outlineColor: customOutline,
          onPressed: () {},
        ),
      ),
    );
    expect(outlineSide(tester), const BorderSide(color: customOutline));

    await tester.pumpWidget(
      host(CLButton(label: '继续', outlined: false, onPressed: () {})),
    );
    expect(outlineSide(tester), BorderSide.none);
  });

  testWidgets('CLButton only ghosts skip the frosted background', (
    WidgetTester tester,
  ) async {
    for (final (variant, frosted) in [
      (CLButtonVariant.primary, true),
      (CLButtonVariant.secondary, true),
      (CLButtonVariant.danger, true),
      (CLButtonVariant.ghost, false),
    ]) {
      await tester.pumpWidget(
        host(CLButton(label: '继续', variant: variant, onPressed: () {})),
      );
      expect(
        tester.widget<CLSurface>(find.byType(CLSurface)).frosted,
        frosted,
        reason: 'frosted state of $variant',
      );
    }
  });

  testWidgets('CLButton semantic variants use contrasting foregrounds', (
    WidgetTester tester,
  ) async {
    final theme = CLThemeData();

    for (final (variant, foreground) in [
      (CLButtonVariant.primary, theme.colors.onAccent),
      (CLButtonVariant.danger, theme.colors.onDanger),
    ]) {
      await tester.pumpWidget(
        host(
          CLButton(
            label: variant.name,
            leadingIcon: const Icon(Icons.add),
            variant: variant,
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.text(variant.name)).style?.color,
        foreground,
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.add))).color,
        foreground,
      );
    }
  });

  testWidgets('CLButton tint overrides the variant fill', (
    WidgetTester tester,
  ) async {
    const tint = Color(0xFF00FF00);

    await tester.pumpWidget(
      host(CLButton(label: '继续', tint: tint, onPressed: () {})),
    );

    final surface = tester.widget<CLSurface>(find.byType(CLSurface));
    expect(surface.fill, tint);
  });

  testWidgets('CLButton disabled dims the fill and blocks taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const CLButton(label: '继续')));

    final theme = CLThemeData();
    final surface = tester.widget<CLSurface>(find.byType(CLSurface));
    expect(surface.fill!.a, lessThan(theme.colors.accent.a));

    final semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(CLButton),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.enabled, isFalse);
  });
}
