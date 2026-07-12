import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claralight_ui/claralight_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('CLButton renders the flat Claralight base', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(CLButton(label: '继续', onPressed: () {})));

    expect(find.byType(CLSurface), findsOneWidget);
    expect(tester.widget<CLSurface>(find.byType(CLSurface)).frosted, isTrue);

    final box = tester.getSize(find.byType(CLSurface));
    expect(box.height, 48);
  });

  testWidgets('CLButton sizes follow the density steps', (
    WidgetTester tester,
  ) async {
    for (final (size, height) in [
      (CLControlSize.small, 28.0),
      (CLControlSize.medium, 36.0),
      (CLControlSize.large, 48.0),
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

  testWidgets('CLButton centers icon and label group with 8px gaps', (
    WidgetTester tester,
  ) async {
    const leftKey = Key('left-icon');
    const rightKey = Key('right-icon');

    await tester.pumpWidget(
      host(
        CLButton(
          width: 260,
          label: '继续',
          leadingIcon: SizedBox(key: leftKey, width: 22, height: 22),
          trailingIcon: SizedBox(key: rightKey, width: 22, height: 22),
          onPressed: () {},
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byType(CLSurface));
    final leftRect = tester.getRect(find.byKey(leftKey));
    final rightRect = tester.getRect(find.byKey(rightKey));
    final textRect = tester.getRect(find.text('继续'));
    final groupCenter = (leftRect.left + rightRect.right) / 2;

    expect(textRect.left - leftRect.right, 8);
    expect(rightRect.left - textRect.right, 8);
    expect(groupCenter, moreOrLessEquals(buttonRect.center.dx));
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
