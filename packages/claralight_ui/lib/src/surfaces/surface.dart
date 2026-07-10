import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// Which layer of the Claralight surface stack a [CLSurface] sits on.
enum CLSurfaceLevel {
  /// Panels, sidebars, sheets — containers on the window background.
  panel,

  /// Rows, fields, buttons — interactive elements on a panel.
  control,

  /// Hovered / raised control.
  controlHighlight,

  /// Selected row / segment fill.
  selection,

  /// Recessed track (segmented control, slider, toggle).
  track,
}

/// The foundational ClaraLight surface: a fill from the [CLColorScheme]
/// layer stack with smooth superellipse corners, plus optional outline
/// and shadow.
class CLSurface extends StatelessWidget {
  final Widget child;

  /// Which stack layer supplies the fill.
  final CLSurfaceLevel level;

  /// Explicit fill color, overriding [level].
  final Color? fill;

  /// Corner radius. Null uses the theme's control radius.
  final BorderRadius? borderRadius;

  /// Optional 1px outline. Pass `true` to use the theme outline color.
  final bool outlined;

  /// Overrides the outline color, e.g. `colors.outlineStrong` for panels.
  final Color? outlineColor;

  /// Frosted-glass mode for floating layers (popovers, dialogs, sheets):
  /// blurs whatever is behind the surface and uses [fill] (defaulting to
  /// `colors.frost`) as a translucent wash on top.
  final bool frosted;

  /// Blur strength of the [frosted] backdrop.
  final double frostSigma;

  /// Optional shadow behind the surface.
  final List<BoxShadow>? shadow;

  /// Padding inside the surface.
  final EdgeInsetsGeometry? padding;

  /// Margin outside the surface.
  final EdgeInsetsGeometry? margin;

  const CLSurface({
    super.key,
    required this.child,
    this.level = CLSurfaceLevel.control,
    this.fill,
    this.borderRadius,
    this.outlined = false,
    this.outlineColor,
    this.frosted = false,
    this.frostSigma = 36,
    this.shadow,
    this.padding,
    this.margin,
  });

  /// The flat fill for [level] under [theme].
  static Color fillFor(CLThemeData theme, CLSurfaceLevel level) {
    final colors = theme.colors;
    return switch (level) {
      CLSurfaceLevel.panel => colors.panel,
      CLSurfaceLevel.control => colors.control,
      CLSurfaceLevel.controlHighlight => colors.controlHighlight,
      CLSurfaceLevel.selection => colors.selection,
      CLSurfaceLevel.track => colors.track,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius =
        borderRadius ?? BorderRadius.circular(theme.radii.control);
    final side = outlined
        ? BorderSide(color: outlineColor ?? theme.colors.outline)
        : BorderSide.none;

    Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    Widget surface;
    if (frosted) {
      surface = Container(
        decoration: clSmoothDecoration(
          borderRadius: radius,
          side: side,
          shadows: shadow,
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: frostSigma, sigmaY: frostSigma),
            child: ColoredBox(
              color: fill ?? theme.colors.frost,
              child: content,
            ),
          ),
        ),
      );
    } else {
      surface = Container(
        decoration: clSmoothDecoration(
          color: fill ?? fillFor(theme, level),
          borderRadius: radius,
          side: side,
          shadows: shadow,
        ),
        child: ClipRSuperellipse(borderRadius: radius, child: content),
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}
