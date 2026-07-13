import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(home: Center(child: child));
  }

  test('CLToolbar keeps its containing capsule by default', () {
    const toolbar = CLToolbar(children: [SizedBox()]);

    expect(toolbar.fill, isNull);
    expect(toolbar.outlined, isTrue);
    expect(toolbar.size, CLControlSize.large);
    expect(toolbar.height, CLControlSize.large.controlHeight);
  });

  testWidgets('size steps use the standard control heights', (tester) async {
    for (final size in CLControlSize.values) {
      const toolbarKey = Key('toolbar');
      await tester.pumpWidget(
        host(
          CLToolbar(
            key: toolbarKey,
            size: size,
            children: const [SizedBox(width: 1)],
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(toolbarKey)).height,
        size.controlHeight,
        reason: 'height of $size',
      );
    }
  });

  testWidgets('passes its size to buttons without explicit sizes', (
    tester,
  ) async {
    const buttonKey = Key('button');
    const iconButtonKey = Key('icon-button');
    await tester.pumpWidget(
      host(
        CLToolbar(
          size: CLControlSize.medium,
          children: [
            CLButton(key: buttonKey, label: 'Save', onPressed: () {}),
            CLIconButton(key: iconButtonKey, icon: Icons.add, onPressed: () {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(buttonKey)).height, 36);
    expect(tester.getSize(find.byKey(iconButtonKey)), const Size.square(36));
  });

  testWidgets('explicit button sizes override the toolbar size', (
    tester,
  ) async {
    const buttonKey = Key('button');
    const iconButtonKey = Key('icon-button');
    await tester.pumpWidget(
      host(
        CLToolbar(
          children: [
            CLButton(
              key: buttonKey,
              label: 'Save',
              size: CLControlSize.small,
              onPressed: () {},
            ),
            CLIconButton(
              key: iconButtonKey,
              icon: Icons.add,
              size: CLControlSize.medium,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(buttonKey)).height, 28);
    expect(tester.getSize(find.byKey(iconButtonKey)), const Size.square(36));
  });

  testWidgets('height only overrides the toolbar capsule', (tester) async {
    const toolbarKey = Key('toolbar');
    const iconButtonKey = Key('icon-button');
    await tester.pumpWidget(
      host(
        CLToolbar(
          key: toolbarKey,
          size: CLControlSize.medium,
          height: 52,
          children: [
            CLIconButton(key: iconButtonKey, icon: Icons.add, onPressed: () {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(toolbarKey)).height, 52);
    expect(tester.getSize(find.byKey(iconButtonKey)), const Size.square(36));
  });

  testWidgets('buttons inherit the nearest toolbar size', (tester) async {
    const innerToolbarKey = Key('inner-toolbar');
    const iconButtonKey = Key('icon-button');
    await tester.pumpWidget(
      host(
        CLToolbar(
          children: [
            CLToolbar(
              key: innerToolbarKey,
              size: CLControlSize.small,
              children: [
                CLIconButton(
                  key: iconButtonKey,
                  icon: Icons.add,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byKey(innerToolbarKey)).height, 28);
    expect(tester.getSize(find.byKey(iconButtonKey)), const Size.square(28));
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
    expect(surfaces.first.outlined, isFalse);
    expect(surfaces.first.shadow, isNull);
    final outline = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(CLSurface).first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.position == DecorationPosition.foreground,
            ),
          )
          .first,
    );
    final outlineShape = (outline.decoration as ShapeDecoration).shape;
    expect(
      (outlineShape as RoundedSuperellipseBorder).side,
      isNot(BorderSide.none),
    );
    expect(surfaces.last.fill, const Color(0x00000000));
    expect(surfaces.last.frosted, isFalse);
  });

  testWidgets(
    'omitted toolbar variants become ghost while explicit variants remain',
    (tester) async {
      const defaultButtonKey = Key('default-button');
      const explicitButtonKey = Key('explicit-button');
      const defaultIconKey = Key('default-icon');
      const explicitIconKey = Key('explicit-icon');
      final theme = CLThemeData();

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: CLToolbar(
              children: [
                CLButton(
                  key: defaultButtonKey,
                  label: 'Default',
                  onPressed: () {},
                ),
                CLButton(
                  key: explicitButtonKey,
                  label: 'Secondary',
                  variant: CLButtonVariant.secondary,
                  onPressed: () {},
                ),
                CLIconButton(
                  key: defaultIconKey,
                  icon: Icons.add,
                  onPressed: () {},
                ),
                CLIconButton(
                  key: explicitIconKey,
                  icon: Icons.add,
                  variant: CLIconButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      CLSurface surface(Key key) => tester.widget<CLSurface>(
        find.descendant(of: find.byKey(key), matching: find.byType(CLSurface)),
      );
      BorderSide outline(Key key) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(key),
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

      for (final key in [defaultButtonKey, defaultIconKey]) {
        expect(surface(key).fill, const Color(0x00000000));
        expect(surface(key).frosted, isFalse);
        expect(outline(key), BorderSide.none);
      }
      for (final key in [explicitButtonKey, explicitIconKey]) {
        expect(surface(key).fill, theme.colors.control);
        expect(surface(key).frosted, isTrue);
        expect(outline(key), BorderSide(color: theme.colors.outline));
      }
    },
  );

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
    expect(surfaces.last.frosted, isFalse);
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
