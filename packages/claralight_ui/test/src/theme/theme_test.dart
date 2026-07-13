import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _backgroundKey = ValueKey('theme-background');
const _textKey = ValueKey('theme-text');

void main() {
  testWidgets('CLTheme updates immediately by default', (tester) async {
    await tester.pumpWidget(_themedApp(const CLColorScheme.dark()));
    expect(_background(tester), const CLColorScheme.dark().background);

    await tester.pumpWidget(_themedApp(const CLColorScheme.light()));
    expect(_background(tester), const CLColorScheme.light().background);
  });

  testWidgets('CLTheme interpolates surfaces and switches foregrounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const CLColorScheme.dark(),
        duration: const Duration(milliseconds: 200),
      ),
    );

    await tester.pumpWidget(
      _themedApp(
        const CLColorScheme.light(),
        duration: const Duration(milliseconds: 200),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      _background(tester),
      Color.lerp(
        const CLColorScheme.dark().background,
        const CLColorScheme.light().background,
        .5,
      ),
    );
    expect(_textColor(tester), const CLColorScheme.light().textPrimary);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_background(tester), const CLColorScheme.light().background);
  });

  testWidgets('CLTheme skips transitions when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const CLColorScheme.dark(),
        duration: const Duration(milliseconds: 200),
        disableAnimations: true,
      ),
    );

    await tester.pumpWidget(
      _themedApp(
        const CLColorScheme.light(),
        duration: const Duration(milliseconds: 200),
        disableAnimations: true,
      ),
    );

    expect(_background(tester), const CLColorScheme.light().background);
  });
}

Widget _themedApp(
  CLColorScheme colors, {
  Duration duration = Duration.zero,
  bool disableAnimations = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: CLTheme(
      data: CLThemeData(colors: colors),
      duration: duration,
      curve: Curves.linear,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: _ThemeProbe(),
      ),
    ),
  );
}

class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final colors = CLTheme.of(context).colors;
    return ColoredBox(
      key: _backgroundKey,
      color: colors.background,
      child: Text(
        'Theme',
        key: _textKey,
        style: TextStyle(color: colors.textPrimary),
      ),
    );
  }
}

Color _background(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(_backgroundKey)).color;

Color? _textColor(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_textKey)).style?.color;
