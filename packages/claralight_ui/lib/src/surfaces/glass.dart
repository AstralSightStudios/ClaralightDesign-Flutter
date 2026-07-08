import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class Glass extends StatelessWidget {
  /// The widget displayed on top of the glass surface.
  final Widget child;

  /// Tint color of the glass. The alpha channel controls intensity.
  final Color backgroundColor;

  /// Background blur strength.
  final double blur;

  /// Refraction depth used by the Impeller liquid-glass renderer.
  final double thickness;

  /// Refraction strength used by the Impeller liquid-glass renderer.
  final double refractiveIndex;

  /// Chromatic fringe strength used by the Impeller liquid-glass renderer.
  final double chromaticAberration;

  /// Directional light intensity used by the Impeller liquid-glass renderer.
  final double lightIntensity;

  /// Ambient highlight strength used by the Impeller liquid-glass renderer.
  final double ambientStrength;

  /// Corner radius of the glass surface.
  final BorderRadius borderRadius;

  /// Whether Impeller should render the surface as a rounded superellipse.
  ///
  /// Set to false for strict rounded-rectangle/capsule parity with platforms
  /// that do not use superellipse geometry.
  final bool useRoundedSuperellipse;

  /// Whether [child] is rendered inside the liquid glass refraction.
  final bool glassContainsChild;

  /// Optional border drawn on top of the surface.
  final BoxBorder? border;

  /// Optional shadow cast behind the surface.
  final List<BoxShadow>? boxShadow;

  /// Padding applied inside the glass surface, around [child].
  final EdgeInsetsGeometry? padding;

  /// Margin applied outside the glass surface.
  final EdgeInsetsGeometry? margin;

  final bool? grouped;

  const Glass({
    super.key,
    required this.child,
    this.backgroundColor = Colors.transparent,
    this.blur = 10,
    this.thickness = 20,
    this.refractiveIndex = 1.2,
    this.chromaticAberration = 0.01,
    this.lightIntensity = 0.5,
    this.ambientStrength = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.useRoundedSuperellipse = true,
    this.glassContainsChild = false,
    this.border = const Border.fromBorderSide(
      BorderSide(color: Colors.transparent),
    ),
    this.boxShadow = const [
      BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 2)),
    ],
    this.padding,
    this.margin,
    this.grouped = false,
  });

  /// Whether the Impeller rendering backend is active.
  bool get _impeller => ui.ImageFilter.isShaderFilterSupported;

  @override
  Widget build(BuildContext context) {
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: _impeller ? _buildImpeller(content) : _buildFallback(content),
    );
  }

  Widget _buildImpeller(Widget content) {
    // LiquidGlass shapes only support a single uniform radius, so we take the
    // top-left radius as the representative value.
    final radius = borderRadius.topLeft.x;

    final shape = useRoundedSuperellipse
        ? LiquidRoundedSuperellipse(borderRadius: radius)
        : LiquidRoundedRectangle(borderRadius: radius);

    if (grouped != null && grouped!) {
      return LiquidGlass.grouped(
        shape: shape,
        glassContainsChild: glassContainsChild,
        child: _borderOverlay(content),
      );
    }

    return LiquidGlass.withOwnLayer(
      settings: LiquidGlassSettings(
        blur: blur,
        glassColor: backgroundColor,
        thickness: thickness,
        refractiveIndex: refractiveIndex,
        chromaticAberration: chromaticAberration,
        lightIntensity: lightIntensity,
        ambientStrength: ambientStrength,
        saturation: 1,
      ),
      shape: shape,
      glassContainsChild: glassContainsChild,
      child: _borderOverlay(content),
    );
  }

  Widget _buildFallback(Widget content) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
          ),
          child: _innerHighlightOverlay(content),
        ),
      ),
    );
  }

  /// Draws [border] on top of the Impeller glass surface.
  Widget _borderOverlay(Widget content) {
    final border = this.border;
    if (border == null) return content;

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: border,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Draws [border] and subtle inner highlights used by the fallback style.
  Widget _innerHighlightOverlay(Widget content) {
    final border = this.border;
    if (border == null) return content;

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: border,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33FFFFFF),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x33FFFFFF),
                  ],
                  stops: [0, 0.05, 0.95, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
