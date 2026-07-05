import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass.dart';

/// A press-responsive circular glass surface inspired by macOS-style controls.
///
/// The surface intentionally has no hover state: it stays visually still when
/// the pointer moves nearby or over it, then expands and brightens only while
/// the pointer is pressed.
class InteractiveGlass extends StatefulWidget {
  /// The widget displayed in the center of the glass control.
  final Widget child;

  /// Called when the glass control is tapped.
  final VoidCallback? onTap;

  /// Width and height of the unpressed circular glass surface.
  final double size;

  /// Scale applied only while the pointer is pressed.
  final double pressedScale;

  /// Background blur strength passed to [Glass].
  final double blur;

  /// Base tint color of the glass surface.
  final Color backgroundColor;

  /// Tint color while pressed.
  final Color pressedBackgroundColor;

  /// Base outline color.
  final Color borderColor;

  /// Outline color while pressed.
  final Color pressedBorderColor;

  /// Padding around [child].
  final EdgeInsetsGeometry padding;

  /// Animation duration for press and release.
  final Duration duration;

  /// Animation curve for press and release.
  final Curve curve;

  const InteractiveGlass({
    super.key,
    required this.child,
    this.onTap,
    this.size = 62,
    this.pressedScale = 1.42,
    this.blur = 18,
    this.backgroundColor = const Color(0x5A4A4A4A),
    this.pressedBackgroundColor = const Color(0x8A777777),
    this.borderColor = const Color(0x26FFFFFF),
    this.pressedBorderColor = const Color(0x66FFFFFF),
    this.padding = const EdgeInsets.all(14),
    this.duration = const Duration(milliseconds: 170),
    this.curve = Curves.easeOutQuart,
  });

  @override
  State<InteractiveGlass> createState() => _InteractiveGlassState();
}

class _InteractiveGlassState extends State<InteractiveGlass> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: widget.duration,
          curve: widget.curve,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _pressed ? 1 : 0),
            duration: widget.duration,
            curve: widget.curve,
            builder: (context, press, child) {
              final blurRadius = ui.lerpDouble(12, 24, press)!;
              final yOffset = ui.lerpDouble(4, 9, press)!;
              final shadowAlpha = (0x42 + (0x22 * press)).round();
              final radius = BorderRadius.circular(widget.size / 2);

              return SizedBox.square(
                dimension: widget.size,
                child: Glass(
                  blur: widget.blur,
                  borderRadius: radius,
                  backgroundColor: Color.lerp(
                    widget.backgroundColor,
                    widget.pressedBackgroundColor,
                    press,
                  )!,
                  border: Border.all(
                    color: Color.lerp(
                      widget.borderColor,
                      widget.pressedBorderColor,
                      press,
                    )!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromARGB(shadowAlpha, 0, 0, 0),
                      blurRadius: blurRadius,
                      offset: Offset(0, yOffset),
                    ),
                  ],
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _highlightOverlay(press),
                        Center(
                          child: Padding(padding: widget.padding, child: child),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _highlightOverlay(double press) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.48, -0.7),
            radius: 1.08,
            colors: [
              Color.lerp(
                const Color(0x2FFFFFFF),
                const Color(0x55FFFFFF),
                press,
              )!,
              Color.lerp(
                const Color(0x10FFFFFF),
                const Color(0x24FFFFFF),
                press,
              )!,
              const Color(0x00FFFFFF),
            ],
            stops: const [0, 0.56, 1],
          ),
        ),
      ),
    );
  }
}
