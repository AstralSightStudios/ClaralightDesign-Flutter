import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CLToolbar keeps its containing capsule by default', () {
    const toolbar = CLToolbar(children: [SizedBox()]);

    expect(toolbar.fill, isNull);
    expect(toolbar.outlined, isTrue);
  });

  testWidgets('keeps the capsule but quiets default icon button backgrounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CLToolbar(
            children: [
              CLIconButton(
                icon: Icons.add,
                size: CLControlSize.medium,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final surfaces = tester
        .widgetList<CLSurface>(find.byType(CLSurface))
        .toList();
    expect(surfaces, hasLength(2));
    expect(surfaces.first.fill, isNull);
    expect(surfaces.first.outlined, isTrue);
    expect(surfaces.last.fill, const Color(0x00000000));
    expect(surfaces.last.frosted, isFalse);
  });

  testWidgets('an explicit icon fill still overrides toolbar defaults', (
    tester,
  ) async {
    const iconFill = Color(0x669900FF);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CLToolbar(
            children: [
              CLIconButton(icon: Icons.add, fill: iconFill, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    final surfaces = tester
        .widgetList<CLSurface>(find.byType(CLSurface))
        .toList();
    expect(surfaces.last.fill, iconFill);
    expect(surfaces.last.frosted, isTrue);
  });

  testWidgets('semantic icon variants keep their colors in a toolbar', (
    tester,
  ) async {
    final theme = CLThemeData();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CLToolbar(
            children: [
              CLIconButton(
                key: const Key('primary'),
                icon: Icons.add,
                variant: CLIconButtonVariant.primary,
                onPressed: () {},
              ),
              CLIconButton(
                key: const Key('danger'),
                icon: Icons.delete_outline,
                variant: CLIconButtonVariant.danger,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    CLSurface surface(String key) => tester.widget<CLSurface>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(CLSurface),
      ),
    );

    expect(surface('primary').fill, theme.colors.accent);
    expect(surface('danger').fill, theme.colors.danger);
    expect(surface('primary').frosted, isTrue);
    expect(surface('danger').frosted, isTrue);
  });

  testWidgets('selected toolbar icon stays neutral in both color schemes', (
    tester,
  ) async {
    for (final colors in const [CLColorScheme.dark(), CLColorScheme.light()]) {
      final theme = CLThemeData(colors: colors);
      await tester.pumpWidget(
        CLTheme(
          data: theme,
          child: MaterialApp(
            home: Center(
              child: CLToolbar(
                children: [
                  CLIconButton(
                    icon: Icons.auto_awesome_outlined,
                    selected: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final surfaces = tester
          .widgetList<CLSurface>(find.byType(CLSurface))
          .toList();
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(CLIconButton),
          matching: find.byType(Icon),
        ),
      );
      expect(surfaces.last.fill, theme.colors.control);
      expect(surfaces.last.frosted, isFalse);
      expect(surfaces.last.outlined, isFalse);
      expect(surfaces.last.outlineColor, isNull);
      expect(icon.color, theme.colors.textSecondary);
    }
  });

  testWidgets('hover takes priority over a selected toolbar state', (
    tester,
  ) async {
    final theme = CLThemeData();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CLToolbar(
            children: [
              CLIconButton(
                icon: Icons.auto_awesome_outlined,
                selected: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    CLSurface iconSurface() =>
        tester.widgetList<CLSurface>(find.byType(CLSurface)).last;
    expect(iconSurface().fill, theme.colors.control);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(CLIconButton)));
    await tester.pump();
    expect(iconSurface().fill, theme.colors.controlHighlight);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(iconSurface().fill, theme.colors.control);
  });

  testWidgets('all dividers hide while any tool is hovered or pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CLToolbar(
            dividers: true,
            children: [
              for (var index = 0; index < 3; index++)
                CLIconButton(
                  key: Key('tool-$index'),
                  icon: Icons.add,
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );

    final toolbar = find.byType(CLToolbar);
    final dividers = find.descendant(
      of: toolbar,
      matching: find.byType(AnimatedOpacity),
    );
    expect(dividers, findsNWidgets(2));
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(1),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('tool-1'))));
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(0),
    );

    await mouse.down(tester.getCenter(find.byKey(const Key('tool-1'))));
    await mouse.up();
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(0),
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(1),
    );

    final touch = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('tool-2'))),
    );
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(0),
    );
    await touch.up();
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(dividers).map((item) => item.opacity),
      everyElement(1),
    );
  });
}
