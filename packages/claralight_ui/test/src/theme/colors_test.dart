import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLColorScheme.light', () {
    const colors = CLColorScheme.light();

    test('matches the Facetory light surface palette', () {
      expect(colors.background, const Color(0xFFF9F6EE));
      expect(colors.panel, const Color(0xFFF4F2EA));
      expect(colors.frost, const Color(0x9CFFFFFF));
      expect(colors.control, const Color(0x1AB0A094));
      expect(colors.controlHighlight, const Color(0x33B0A094));
      expect(colors.floatingControl, const Color(0x9B000000));
      expect(colors.onFloatingControl, const Color(0xFFFFFFFF));
      expect(colors.textPrimary, const Color(0xFF160A01));
      expect(colors.textSecondary, const Color(0xE6160A01));
      expect(colors.textTertiary, const Color(0xBF160A01));
      expect(colors.accent, const Color(0xFF0090FF));
      expect(colors.brightness, Brightness.light);
    });

    test('copyWith customizes the floating control pair', () {
      const fill = Color(0xAA112233);
      const foreground = Color(0xFFABCDEF);
      final customized = const CLColorScheme.light().copyWith(
        floatingControl: fill,
        onFloatingControl: foreground,
      );

      expect(customized.floatingControl, fill);
      expect(customized.onFloatingControl, foreground);
    });

    test('keeps hint text readable on the page background', () {
      final renderedHint = Color.alphaBlend(colors.textHint, colors.background);
      final lighter = colors.background.computeLuminance();
      final darker = renderedHint.computeLuminance();
      final contrast = (lighter + 0.05) / (darker + 0.05);

      expect(contrast, greaterThanOrEqualTo(4.5));
    });
  });
}
