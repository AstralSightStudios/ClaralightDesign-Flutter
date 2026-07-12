import 'package:flutter/widgets.dart';

/// ClaraLight corner smoothing.
///
/// Every rounded corner in the design language is a **rounded
/// superellipse** (the iOS "squircle"), not a plain circular arc: the
/// curvature builds up gradually, so surfaces read as one continuous
/// smooth outline.
///
/// Use [clSmoothShape] wherever a `ShapeBorder` is needed and
/// [ClipRSuperellipse] for clipping.
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
