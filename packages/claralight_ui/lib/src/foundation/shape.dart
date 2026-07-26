import 'package:flutter/widgets.dart';

/// ClaraLight corner smoothing.
///
/// Every rounded corner in the design language is a **rounded
/// superellipse** (the iOS "squircle"), not a plain circular arc: the
/// curvature builds up gradually, so surfaces read as one continuous
/// smooth outline.
///
/// Use [clSmoothShape] wherever a `ShapeBorder` is needed and
/// [CLSmoothClip] for clipping.
RoundedSuperellipseBorder clSmoothShape(
  BorderRadiusGeometry borderRadius, {
  BorderSide side = BorderSide.none,
}) {
  return RoundedSuperellipseBorder(borderRadius: borderRadius, side: side);
}

/// [ShapeDecoration] with the ClaraLight smooth corner shape.
ShapeDecoration clSmoothDecoration({
  required BorderRadiusGeometry borderRadius,
  Color? color,
  BorderSide side = BorderSide.none,
  List<BoxShadow>? shadows,
}) {
  return ShapeDecoration(
    color: color,
    shape: clSmoothShape(borderRadius, side: side),
    shadows: shadows,
  );
}

/// The corner clip that pairs with [clSmoothShape] decorations.
///
/// A shape-border path keeps clipping identical to painted smooth surfaces,
/// including per-corner radii, without relying on the engine's
/// [ClipRSuperellipse] save-layer behavior.
class CLSmoothClip extends StatelessWidget {
  const CLSmoothClip({super.key, required this.borderRadius, this.child});

  final BorderRadiusGeometry borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: ShapeBorderClipper(shape: clSmoothShape(borderRadius)),
    child: child,
  );
}
