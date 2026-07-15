import 'package:flutter/widgets.dart';

/// The ClaraLight color scheme.
///
/// ClaraLight is a quiet, layered dark design language. Surfaces stack
/// from [background] (window) through
/// [panel] (inspector panes, sheets) to [control] (rows, fields, buttons).
/// Control fills are translucent white overlays so the same layer reads
/// correctly over any surface underneath. Color is used sparingly: [accent]
/// marks the primary action and selection, the status colors mark meaning,
/// everything else stays neutral.
@immutable
class CLColorScheme {
  /// Window / canvas background (Figma `General/页面底色`).
  final Color background;

  /// Large containers sitting on [background]: panels, sheets, sidebars.
  final Color panel;

  /// Translucent fill of frosted floating layers (menus, popovers,
  /// dialogs, sheets) — pairs with a backdrop blur.
  final Color frost;

  /// Interactive surfaces: rows, fields, buttons, chips
  /// (Figma `Overlays/White Alpha/2`).
  final Color control;

  /// [control] while hovered or gently raised (`White Alpha/3`).
  final Color controlHighlight;

  /// Dark translucent fill for controls floating over arbitrary canvas
  /// content (Figma `Colors/Gray Alpha/11`).
  final Color floatingControl;

  /// Text/icons placed on top of [floatingControl].
  final Color onFloatingControl;

  /// Fill of the selected row / segment and the scrollbar thumb.
  final Color selection;

  /// Recessed track behind segmented controls, sliders and toggles.
  final Color track;

  /// Hairline between rows and groups (solid or dashed).
  final Color separator;

  /// 1px outline around controls and dialogs.
  final Color outline;

  /// Stronger 1px outline around floating panels and sheets.
  final Color outlineStrong;

  /// Primary text and icons: titles, selected rows.
  final Color textPrimary;

  /// Standard row and body text.
  final Color textSecondary;

  /// Subtitles, units, field prefixes.
  final Color textTertiary;

  /// Section headers, placeholders, unselected segments.
  final Color textHint;

  /// Disabled text and icons.
  final Color textDisabled;

  /// Claralight blue (Figma `Colors/Blue/9`). Primary actions, focus,
  /// canvas selection.
  final Color accent;

  /// Translucent accent fill behind emphasized actions
  /// (Figma `Colors/Blue Alpha/6`).
  final Color accentBackground;

  /// Text/icons placed on top of [accent].
  final Color onAccent;

  /// Checked selection controls — checklist marks and opt-in switches
  /// (Figma `Colors/Indigo/9`). Distinct from [accent] so primary actions
  /// and passive "which one is chosen" marks read differently.
  final Color selectionAccent;

  /// Positive state (toggle on, success).
  final Color success;

  /// Warning state (Figma `Semantic/Warning/10`).
  final Color warning;

  /// Translucent fill behind warning banners (`Warning Alpha/2`).
  final Color warningBackground;

  /// Destructive state (Figma `Semantic/Error/9`).
  final Color danger;

  /// Translucent fill behind error badges (`Error Alpha/3`).
  final Color dangerBackground;

  /// Text/icons placed on top of [danger].
  final Color onDanger;

  /// Barrier behind dialogs and sheets.
  final Color scrim;

  /// Whether this scheme is dark.
  final Brightness brightness;

  const CLColorScheme({
    required this.background,
    required this.panel,
    required this.frost,
    required this.control,
    required this.controlHighlight,
    this.floatingControl = const Color(0x9B000000),
    this.onFloatingControl = const Color(0xFFFFFFFF),
    required this.selection,
    required this.track,
    required this.separator,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.textDisabled,
    required this.accent,
    required this.accentBackground,
    required this.onAccent,
    this.selectionAccent = const Color(0xFF3E63DD),
    required this.success,
    required this.warning,
    required this.warningBackground,
    required this.danger,
    required this.dangerBackground,
    required this.onDanger,
    required this.scrim,
    required this.brightness,
  });

  /// The reference ClaraLight scheme, matching the design's Figma source
  /// (the Facetory demo app).
  const CLColorScheme.dark()
    : this(
        background: const Color(0xFF191919),
        panel: const Color(0xFF111111),
        frost: const Color(0xBF161616),
        control: const Color(0x1AFFFFFF),
        controlHighlight: const Color(0x26FFFFFF),
        floatingControl: const Color(0x9B000000),
        onFloatingControl: const Color(0xFFFFFFFF),
        selection: const Color(0x29FFFFFF),
        track: const Color(0x1AFFFFFF),
        separator: const Color(0x1AFFFFFF),
        outline: const Color(0x26FFFFFF),
        outlineStrong: const Color(0x4DFFFFFF),
        textPrimary: const Color(0xFFFFFFFF),
        textSecondary: const Color(0xE5FFFFFF),
        textTertiary: const Color(0xBFFFFFFF),
        textHint: const Color(0x66FFFFFF),
        textDisabled: const Color(0x59FFFFFF),
        accent: const Color(0xFF0090FF),
        accentBackground: const Color(0x530088F6),
        onAccent: const Color(0xFFFFFFFF),
        success: const Color(0xFF30D158),
        warning: const Color(0xFFFFBA18),
        warningBackground: const Color(0x16F4D100),
        danger: const Color(0xFFE5484D),
        dangerBackground: const Color(0x14F3000D),
        onDanger: const Color(0xFFFFFFFF),
        scrim: const Color(0x73000000),
        brightness: Brightness.dark,
      );

  /// The warm light scheme from the Facetory desktop design.
  const CLColorScheme.light()
    : this(
        background: const Color(0xFFF9F6EE),
        panel: const Color(0xFFF4F2EA),
        frost: const Color(0x9CFFFFFF),
        control: const Color(0x1AB0A094),
        controlHighlight: const Color(0x33B0A094),
        floatingControl: const Color(0x9CFFFFFF),
        onFloatingControl: const Color(0xFF160A01),
        selection: const Color(0x1AB0A094),
        track: const Color(0x1AB0A094),
        separator: const Color(0x1A160A01),
        outline: const Color(0x29160A01),
        outlineStrong: const Color(0x4D160A01),
        textPrimary: const Color(0xFF160A01),
        textSecondary: const Color(0xE6160A01),
        textTertiary: const Color(0xBF160A01),
        textHint: const Color(0x9E160A01),
        textDisabled: const Color(0x52160A01),
        accent: const Color(0xFF0090FF),
        accentBackground: const Color(0x290090FF),
        onAccent: const Color(0xFFFFFFFF),
        success: const Color(0xFF34C759),
        warning: const Color(0xFFC7871E),
        warningBackground: const Color(0x16F4D100),
        danger: const Color(0xFFE5484D),
        dangerBackground: const Color(0x14F3000D),
        onDanger: const Color(0xFFFFFFFF),
        scrim: const Color(0x59000000),
        brightness: Brightness.light,
      );

  CLColorScheme copyWith({
    Color? background,
    Color? panel,
    Color? frost,
    Color? control,
    Color? controlHighlight,
    Color? floatingControl,
    Color? onFloatingControl,
    Color? selection,
    Color? track,
    Color? separator,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? textDisabled,
    Color? accent,
    Color? accentBackground,
    Color? onAccent,
    Color? selectionAccent,
    Color? success,
    Color? warning,
    Color? warningBackground,
    Color? danger,
    Color? dangerBackground,
    Color? onDanger,
    Color? scrim,
    Brightness? brightness,
  }) {
    return CLColorScheme(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      frost: frost ?? this.frost,
      control: control ?? this.control,
      controlHighlight: controlHighlight ?? this.controlHighlight,
      floatingControl: floatingControl ?? this.floatingControl,
      onFloatingControl: onFloatingControl ?? this.onFloatingControl,
      selection: selection ?? this.selection,
      track: track ?? this.track,
      separator: separator ?? this.separator,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textHint: textHint ?? this.textHint,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      accentBackground: accentBackground ?? this.accentBackground,
      onAccent: onAccent ?? this.onAccent,
      selectionAccent: selectionAccent ?? this.selectionAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningBackground: warningBackground ?? this.warningBackground,
      danger: danger ?? this.danger,
      dangerBackground: dangerBackground ?? this.dangerBackground,
      onDanger: onDanger ?? this.onDanger,
      scrim: scrim ?? this.scrim,
      brightness: brightness ?? this.brightness,
    );
  }
}
