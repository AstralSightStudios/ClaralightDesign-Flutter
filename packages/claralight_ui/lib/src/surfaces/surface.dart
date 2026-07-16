import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
    final radius = borderRadius ?? BorderRadius.circular(theme.radii.control);
    final side = outlined
        ? BorderSide(color: outlineColor ?? theme.colors.outline)
        : BorderSide.none;

    Widget content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    Widget surface;
    if (frosted) {
      surface = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: side == BorderSide.none
                ? EdgeInsets.zero
                : EdgeInsets.all(side.width),
            child: ClipRSuperellipse(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: frostSigma,
                  sigmaY: frostSigma,
                ),
                child: ColoredBox(
                  color: fill ?? theme.colors.frost,
                  child: content,
                ),
              ),
            ),
          ),
          if ((shadow?.isNotEmpty ?? false) || side != BorderSide.none)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FrostedSurfaceChrome(
                    borderRadius: radius,
                    side: side,
                    shadows: shadow ?? const [],
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      surface = Container(
        decoration: clSmoothDecoration(
          color: fill ?? fillFor(theme, level),
          borderRadius: radius,
          side: side,
          shadows: shadow,
        ),
        child: CLSmoothClip(borderRadius: radius, child: content),
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

class _FrostedSurfaceChrome extends CustomPainter {
  final BorderRadius borderRadius;
  final BorderSide side;
  final List<BoxShadow> shadows;

  const _FrostedSurfaceChrome({
    required this.borderRadius,
    required this.side,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = clSmoothShape(borderRadius);

    if (shadows.isNotEmpty) {
      final extent = shadows.fold<double>(0, (current, shadow) {
        final shadowExtent =
            shadow.blurRadius * 2 +
            shadow.spreadRadius.abs() +
            shadow.offset.dx.abs() +
            shadow.offset.dy.abs();
        return math.max(current, shadowExtent);
      });
      final shadowPainter = clSmoothDecoration(
        borderRadius: borderRadius,
        shadows: shadows,
      ).createBoxPainter(() {});

      canvas.saveLayer(rect.inflate(extent), Paint());
      shadowPainter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
      canvas.drawPath(
        shape.getOuterPath(rect),
        Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true,
      );
      canvas.restore();
      shadowPainter.dispose();
    }

    if (side != BorderSide.none) {
      clSmoothShape(borderRadius, side: side).paint(canvas, rect);
    }
  }

  @override
  bool shouldRepaint(_FrostedSurfaceChrome oldDelegate) {
    return borderRadius != oldDelegate.borderRadius ||
        side != oldDelegate.side ||
        !listEquals(shadows, oldDelegate.shadows);
  }
}
