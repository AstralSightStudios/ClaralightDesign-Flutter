import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'glass.dart';

/// A press-responsive glass surface inspired by macOS-style controls.
///
/// The surface intentionally has no hover state: it stays visually still when
/// the pointer moves nearby or over it, then expands and brightens only while
/// the pointer is pressed. Dragging while pressed softly deforms the surface.
class InteractiveGlass extends StatefulWidget {
  /// The widget displayed in the center of the glass control.
  final Widget child;

  /// Called when the glass control is tapped.
  final VoidCallback? onTap;

  /// Width and height of the unpressed square glass surface.
  ///
  /// Ignored per axis when [width] or [height] is provided.
  final double size;

  /// Width of the glass surface. Defaults to [size].
  final double? width;

  /// Height of the glass surface. Defaults to [size].
  final double? height;

  /// Corner radius of the glass surface.
  ///
  /// Defaults to a pill/circle radius based on the shorter side.
  final BorderRadius? borderRadius;

  /// Scale applied only while the pointer is pressed.
  final double pressedScale;

  /// Background blur strength passed to [Glass].
  final double blur;

  /// Base tint color of the glass surface.
  final Color backgroundColor;

  /// Tint color while pressed.
  final Color pressedBackgroundColor;

  /// Optional border passed directly to [Glass].
  ///
  /// Pressing the surface never mutates this border.
  final BoxBorder? border;

  /// Optional shadow passed directly to [Glass].
  ///
  /// When omitted, InteractiveGlass uses a subtle press-responsive shadow.
  final List<BoxShadow>? boxShadow;

  /// Padding around [child].
  final EdgeInsetsGeometry padding;

  /// Animation duration for press and release.
  final Duration duration;

  /// Animation curve for press and release.
  final Curve curve;

  /// Resistance applied to drag deformation.
  ///
  /// Higher values make the glass feel harder to pull and deform less.
  final double dragTension;

  /// Spring used when drag deformation returns to rest.
  final SpringDescription spring;

  const InteractiveGlass({
    super.key,
    required this.child,
    this.onTap,
    this.size = 44,
    this.width,
    this.height,
    this.borderRadius,
    this.pressedScale = 1.35,
    this.blur = 18,
    this.backgroundColor = const Color(0x5A4A4A4A),
    this.pressedBackgroundColor = const Color(0x8A777777),
    this.border = const Border.fromBorderSide(
      BorderSide(color: Colors.transparent),
    ),
    this.boxShadow,
    this.padding = EdgeInsets.zero,
    this.duration = const Duration(milliseconds: 170),
    this.curve = Curves.easeOutQuart,
    this.dragTension = 1.8,
    this.spring = const SpringDescription(mass: 1, stiffness: 520, damping: 16),
  }) : assert(size > 0 && size < double.infinity),
       assert(width == null || (width > 0 && width < double.infinity)),
       assert(height == null || (height > 0 && height < double.infinity)),
       assert(dragTension > 0 && dragTension < double.infinity);

  @override
  State<InteractiveGlass> createState() => _InteractiveGlassState();
}

class _InteractiveGlassState extends State<InteractiveGlass>
    with TickerProviderStateMixin {
  static const _scaleKey = Key('interactive-glass-scale-transform');
  static const _deformationKey = Key('interactive-glass-deformation-transform');
  static const _surfaceKey = Key('interactive-glass-surface');

  late final AnimationController _scaleController;
  late final AnimationController _dragSpringController;

  bool _pressed = false;
  int? _activePointer;
  Offset _pressOrigin = Offset.zero;
  Offset _dragOffset = Offset.zero;
  Offset _springStartOffset = Offset.zero;

  double get _surfaceWidth => widget.width ?? widget.size;

  double get _surfaceHeight => widget.height ?? widget.size;

  BorderRadius get _surfaceBorderRadius =>
      widget.borderRadius ??
      BorderRadius.circular(math.min(_surfaceWidth, _surfaceHeight) / 2);

  double get _deformationExtent => math.max(_surfaceWidth, _surfaceHeight);

  double get _scale =>
      ui.lerpDouble(1, widget.pressedScale, _scaleController.value)!;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    _dragSpringController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _dragOffset = _springStartOffset * _dragSpringController.value;
        });
      });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _dragSpringController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _scaleController.stop();
    _dragSpringController.stop();
    _scaleController.animateTo(
      1,
      duration: widget.duration,
      curve: widget.curve,
    );
    setState(() {
      _activePointer = event.pointer;
      _pressOrigin = event.localPosition;
      _dragOffset = Offset.zero;
      _springStartOffset = Offset.zero;
      _pressed = true;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    setState(() {
      _dragOffset = (event.localPosition - _pressOrigin) / widget.dragTension;
    });
  }

  void _handlePointerRelease(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _pressed = false;
    _startScaleSpringReturn();
    _startDragSpringReturn();
  }

  void _startScaleSpringReturn() {
    _scaleController.animateWith(
      SpringSimulation(
        widget.spring,
        _scaleController.value,
        0,
        0,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    setState(() {});
  }

  void _startDragSpringReturn() {
    if (_dragOffset == Offset.zero) {
      setState(() {
        _springStartOffset = Offset.zero;
        _pressed = false;
      });
      return;
    }

    _springStartOffset = _dragOffset;
    _dragSpringController.value = 1;
    _dragSpringController.animateWith(
      SpringSimulation(
        widget.spring,
        1,
        0,
        0,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    setState(() {});
  }

  Matrix4 _deformationMatrix(Offset dragOffset) {
    final normalizedDistance = (dragOffset.distance / _deformationExtent).clamp(
      0.0,
      1.0,
    );
    if (normalizedDistance == 0) return Matrix4.identity();

    final stretch = 1 + normalizedDistance * 0.18;
    final squash = 1 - normalizedDistance * 0.08;
    final angle = math.atan2(dragOffset.dy, dragOffset.dx);

    return Matrix4.identity()
      ..translateByDouble(dragOffset.dx * 0.08, dragOffset.dy * 0.08, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(stretch, squash, 1, 1)
      ..rotateZ(-angle);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerRelease,
      onPointerCancel: _handlePointerRelease,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Transform(
          key: _scaleKey,
          alignment: Alignment.center,
          transform: Matrix4.identity()..scaleByDouble(_scale, _scale, 1, 1),
          child: Transform(
            key: _deformationKey,
            alignment: Alignment.center,
            transform: _deformationMatrix(_dragOffset),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _pressed ? 1 : 0),
              duration: widget.duration,
              curve: widget.curve,
              builder: (context, press, child) {
                final blurRadius = ui.lerpDouble(12, 24, press)!;
                final yOffset = ui.lerpDouble(4, 9, press)!;
                final shadowAlpha = (0x42 + (0x22 * press)).round();
                final radius = _surfaceBorderRadius;
                final boxShadow =
                    widget.boxShadow ??
                    [
                      BoxShadow(
                        color: Color.fromARGB(shadowAlpha, 0, 0, 0),
                        blurRadius: blurRadius,
                        offset: Offset(0, yOffset),
                      ),
                    ];

                return SizedBox(
                  key: _surfaceKey,
                  width: _surfaceWidth,
                  height: _surfaceHeight,
                  child: Glass(
                    blur: widget.blur,
                    borderRadius: radius,
                    backgroundColor: Color.lerp(
                      widget.backgroundColor,
                      widget.pressedBackgroundColor,
                      press,
                    )!,
                    border: widget.border,
                    boxShadow: boxShadow,
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _highlightOverlay(press),
                          Center(
                            child: Padding(
                              padding: widget.padding,
                              child: child,
                            ),
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
