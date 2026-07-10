import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// The Claralight press interaction, independent of the surface it wraps.
///
/// Adds the signature springy feel to any child — typically a [CLSurface]:
///
/// * a quick scale-up on press that springs back with overshoot on release;
/// * an optional jelly deformation while the pointer drags;
/// * an optional soft highlight that follows the pointer.
class CLPressable extends StatefulWidget {
  final Widget child;

  /// Called on tap/release inside the surface. Null disables interaction.
  final VoidCallback? onTap;

  /// Corner radius used to clip the pointer highlight.
  final BorderRadius borderRadius;

  /// Scale while pressed. 1.0 disables the scale response.
  final double pressedScale;

  /// Whether dragging deforms the surface like soft jelly.
  final bool deformOnDrag;

  /// Whether the pointer-following highlight is drawn.
  final bool showHighlight;

  /// Resistance applied to drag deformation. Higher = stiffer.
  final double dragTension;

  /// Spring used for the release return.
  final SpringDescription spring;

  /// Press-in animation duration and curve.
  final Duration duration;
  final Curve curve;

  const CLPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.pressedScale = 1 + 4 / 48,
    this.deformOnDrag = true,
    this.showHighlight = true,
    this.dragTension = 1.8,
    this.spring = const SpringDescription(mass: 1, stiffness: 520, damping: 16),
    this.duration = const Duration(milliseconds: 170),
    this.curve = Curves.easeOutQuart,
  });

  @override
  State<CLPressable> createState() => _CLPressableState();
}

class _CLPressableState extends State<CLPressable>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _dragReturn;
  late final AnimationController _highlight;

  int? _activePointer;
  Offset _pressOrigin = Offset.zero;
  Offset _dragOffset = Offset.zero;
  Offset _dragReturnStart = Offset.zero;
  Offset _pointerPosition = Offset.zero;

  bool get _enabled => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}));
    _dragReturn = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _dragOffset = _dragReturnStart * _dragReturn.value;
        });
      });
    _highlight = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scale.dispose();
    _dragReturn.dispose();
    _highlight.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled || _activePointer != null) return;
    _scale.stop();
    _dragReturn.stop();
    _scale.animateTo(1, duration: widget.duration, curve: widget.curve);
    _highlight.forward();
    setState(() {
      _activePointer = event.pointer;
      _pressOrigin = event.localPosition;
      _pointerPosition = event.localPosition;
      _dragOffset = Offset.zero;
      _dragReturnStart = Offset.zero;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    setState(() {
      if (widget.deformOnDrag) {
        _dragOffset =
            (event.localPosition - _pressOrigin) / widget.dragTension;
      }
      _pointerPosition = event.localPosition;
    });
  }

  void _handlePointerRelease(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _highlight.reverse();
    _scale.animateWith(
      SpringSimulation(widget.spring, _scale.value, 0, 0,
          tolerance: Tolerance.defaultTolerance),
    );
    if (_dragOffset != Offset.zero) {
      _dragReturnStart = _dragOffset;
      _dragReturn.value = 1;
      _dragReturn.animateWith(
        SpringSimulation(widget.spring, 1, 0, 0,
            tolerance: Tolerance.defaultTolerance),
      );
    }
    setState(() {});
  }

  double get _scaleValue =>
      ui.lerpDouble(1, widget.pressedScale, _scale.value)!;

  Matrix4 _deformationMatrix(Size size) {
    final extent = math.max(size.width, size.height);
    final normalized =
        extent == 0 ? 0.0 : (_dragOffset.distance / extent).clamp(0.0, 1.0);
    if (normalized == 0) return Matrix4.identity();

    final stretch = 1 + normalized * 0.18;
    final squash = 1 - normalized * 0.08;
    final angle = math.atan2(_dragOffset.dy, _dragOffset.dx);

    return Matrix4.identity()
      ..translateByDouble(_dragOffset.dx * 0.08, _dragOffset.dy * 0.08, 0, 1)
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            Widget result = widget.child;

            if (widget.showHighlight) {
              result = Stack(
                fit: StackFit.passthrough,
                children: [
                  result,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRSuperellipse(
                        borderRadius: widget.borderRadius,
                        child: CustomPaint(
                          painter: _HighlightPainter(
                            pointer: _pointerPosition,
                            press:
                                Curves.easeOut.transform(_highlight.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (widget.deformOnDrag) {
              result = Transform(
                alignment: Alignment.center,
                transform: _deformationMatrix(size),
                child: result,
              );
            }

            if (widget.pressedScale != 1) {
              result = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(_scaleValue, _scaleValue, 1, 1),
                child: result,
              );
            }

            return result;
          },
        ),
      ),
    );
  }

}

/// A dim, wide light that sits exactly under the pointer.
///
/// Painted as a true circle in pixel space (never stretched to the box
/// like a box-fitted [RadialGradient]), with most of the energy in the
/// outer falloff so it reads as light diffusing through the surface
/// rather than a spotlight.
class _HighlightPainter extends CustomPainter {
  final Offset pointer;
  final double press;

  const _HighlightPainter({required this.pointer, required this.press});

  @override
  void paint(Canvas canvas, Size size) {
    if (press <= 0.01 || size.isEmpty) return;

    final radius = math.max(size.width, size.height) * 1.1;
    final alpha = 0.10 * press;
    final center = Color.fromRGBO(255, 255, 255, alpha);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          center,
          center.withValues(alpha: alpha * 0.55),
          center.withValues(alpha: alpha * 0.18),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: pointer, radius: radius))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(pointer, radius, glow);
  }

  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) =>
      pointer != oldDelegate.pointer || press != oldDelegate.press;
}
