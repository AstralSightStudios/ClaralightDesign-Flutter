import 'package:flutter/widgets.dart';

/// Claralight type ramp.
///
/// Three bundled families (see `fonts/FONTS.md`):
///
/// * **MiSans** — every UI style, Chinese + Latin.
/// * **Sarasa Mono SC** — [mono]/[monoStrong]: numeric values and units
///   (`368KB/1024KB`, `78x91px`, `00:00`).
/// * **ChillDINGothic** — [display]: large DIN-flavored headings.
///
/// All styles omit color; widgets resolve color from [CLColorScheme] so one
/// ramp serves both schemes.
@immutable
class CLTypography {
  // Fonts declared inside a package must be referenced with the
  // `packages/<package>/` prefix, otherwise Flutter silently falls back
  // to system fonts (wrong weights, no mono).

  /// The bundled UI family (variable font).
  static const String uiFamily = 'packages/claralight_ui/MiSans';

  /// The bundled monospace family for values and units.
  static const String monoFamily = 'packages/claralight_ui/Sarasa Mono SC';

  /// The bundled display family for large headings.
  static const String displayFamily = 'packages/claralight_ui/ChillDINGothic';

  /// Maps a [FontWeight] onto MiSans VF's non-standard `wght` axis
  /// (Regular sits at 330, not 400; the axis spans 150–700).
  static double miSansWght(FontWeight weight) => switch (weight) {
        FontWeight.w100 => 150,
        FontWeight.w200 => 200,
        FontWeight.w300 => 250,
        FontWeight.w400 => 330,
        FontWeight.w500 => 380,
        FontWeight.w600 => 450,
        FontWeight.w700 => 520,
        FontWeight.w800 => 630,
        _ => 700,
      };

  /// Font family used across the design language.
  final String fontFamily;

  /// Fallback families when [fontFamily] is unavailable.
  final List<String> fontFamilyFallback;

  /// Large display headings in ChillDINGothic (hero text, brand titles).
  final TextStyle display;

  /// Panel and sheet titles (e.g. "神秘表盘").
  final TextStyle headline;

  /// Dialog titles and prominent rows.
  final TextStyle title;

  /// Default body: list rows, button labels.
  final TextStyle body;

  /// Dense controls: property-row labels, chips, subtitles.
  final TextStyle callout;

  /// Section headers ("表盘样式", "对齐") and small button labels.
  final TextStyle label;

  /// Captions and footnotes.
  final TextStyle caption;

  /// Monospace values: dimensions, memory readouts, time codes.
  final TextStyle mono;

  /// Emphasized monospace values (the number part of `12px`).
  final TextStyle monoStrong;

  const CLTypography({
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.callout,
    required this.label,
    required this.caption,
    required this.mono,
    required this.monoStrong,
  });

  factory CLTypography.standard({
    String fontFamily = uiFamily,
    List<String> fontFamilyFallback = const [
      'MiSans',
      'MiSans VF',
      'PingFang SC',
      'SF Pro Text',
      'Roboto',
    ],
  }) {
    TextStyle style(double size, FontWeight weight, double height,
        [double letterSpacing = 0]) {
      return TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', miSansWght(weight))],
        height: height / size,
        letterSpacing: letterSpacing,
        decoration: TextDecoration.none,
      );
    }

    TextStyle mono(double size, FontWeight weight) {
      return TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: [fontFamily, ...fontFamilyFallback],
        fontSize: size,
        fontWeight: weight,
        height: 1.3,
        decoration: TextDecoration.none,
      );
    }

    return CLTypography(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      display: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: [fontFamily, ...fontFamilyFallback],
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 38 / 30,
        decoration: TextDecoration.none,
      ),
      headline: style(18, FontWeight.w700, 24, -0.55),
      title: style(16, FontWeight.w600, 21, -0.4),
      body: style(15, FontWeight.w500, 20, -0.5),
      callout: style(14, FontWeight.w600, 19, -0.5),
      label: style(13, FontWeight.w700, 17, -0.2),
      caption: style(12, FontWeight.w400, 16, 0),
      mono: mono(14, FontWeight.w400),
      monoStrong: mono(14, FontWeight.w600),
    );
  }

  static final _wghtCache = <FontWeight, List<FontVariation>>{};

  /// The [FontVariation] list matching [weight] on MiSans VF.
  static List<FontVariation> variationsFor(FontWeight weight) =>
      _wghtCache[weight] ??= [FontVariation('wght', miSansWght(weight))];

  CLTypography copyWith({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? body,
    TextStyle? callout,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? mono,
    TextStyle? monoStrong,
  }) {
    return CLTypography(
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      body: body ?? this.body,
      callout: callout ?? this.callout,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      mono: mono ?? this.mono,
      monoStrong: monoStrong ?? this.monoStrong,
    );
  }
}

/// Weight changes on ClaraLight text styles.
///
/// MiSans ships as a variable font, and a bare `copyWith(fontWeight:)`
/// does not move a variable font's `wght` axis — use this instead:
///
/// ```dart
/// theme.typography.body.withCLWeight(FontWeight.w600)
/// ```
extension CLTextStyleWeight on TextStyle {
  TextStyle withCLWeight(FontWeight weight) {
    return copyWith(
      fontWeight: weight,
      fontVariations: CLTypography.variationsFor(weight),
    );
  }
}
