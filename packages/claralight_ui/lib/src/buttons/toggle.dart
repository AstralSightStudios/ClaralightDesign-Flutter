import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../surfaces/glass.dart';

/// A liquid-style toggle switch inspired by the Android Compose
/// [LiquidToggle] component.
///
/// The track is a 64x28 dp capsule whose color interpolates between a
/// neutral track tint and the system accent color. The thumb is a 40x24 dp
/// glass capsule that can be dragged or tapped to toggle [value].
class CLToggle extends StatefulWidget {
  /// Whether the switch is currently on.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool>? onChanged;

  const CLToggle({super.key, required this.value, this.onChanged});

  /// Track width in logical pixels.
  static const double trackWidth = 64;

  /// Track height in logical pixels.
  static const double trackHeight = 28;

  /// Thumb width in logical pixels.
  static const double thumbWidth = 40;

  /// Thumb height in logical pixels.
  static const double thumbHeight = 24;

  /// Horizontal padding between the track edges and the thumb travel bounds.
  static const double thumbPadding = 2;

  /// Horizontal distance the thumb travels between on/off states.
  static const double dragWidth = 20;

  @override
  State<CLToggle> createState() => _CLToggleState();
}

class _CLToggleState extends State<CLToggle> with TickerProviderStateMixin {
  static const Key _trackKey = Key('cl-toggle-track');
  static const Key _thumbKey = Key('cl-toggle-thumb');
  static const Key _thumbSurfaceKey = Key('cl-toggle-thumb-surface');

  late final AnimationController _fractionController;
  late final AnimationController _pressController;

  var _didDrag = false;
  double _currentFraction = 0;
  double _pressProgress = 0;
  double _dragStartFraction = 0;
  double _dragVelocity = 0;
  Offset _dragStartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentFraction = widget.value ? 1 : 0;

    _fractionController = AnimationController.unbounded(
      value: _currentFraction,
      vsync: this,
    )..addListener(_onFractionChanged);

    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    )..addListener(_onPressChanged);

    _pressProgress = _pressController.value;
  }

  @override
  void didUpdateWidget(CLToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.value ? 1.0 : 0.0;
    if (target != _currentFraction) {
      _animateFractionTo(target);
    }
  }

  @override
  void dispose() {
    _fractionController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onFractionChanged() {
    setState(() {
      _currentFraction = _fractionController.value.clamp(0, 1);
    });
  }

  void _onPressChanged() {
    setState(() {
      _pressProgress = _pressController.value;
    });
  }

  void _animateFractionTo(double target) {
    _fractionController.animateWith(
      SpringSimulation(
        _kSpring,
        _fractionController.value,
        target,
        0,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
  }

  void _commitSelectedChange(bool selected) {
    _fractionController.value = selected ? 1 : 0;
    widget.onChanged!(selected);
    _scheduleControlledResync(selected);
  }

  void _scheduleControlledResync(bool requestedValue) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.value == requestedValue) return;
      _animateFractionTo(widget.value ? 1 : 0);
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.onChanged == null) return;
    _didDrag = false;
    _dragStartFraction = _currentFraction;
    _dragStartPosition = event.position;
    _pressController.forward();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (widget.onChanged == null) return;
    final direction = _isLtr(context) ? 1 : -1;
    final dx = event.position.dx - _dragStartPosition.dx;

    if (!_didDrag && dx != 0) {
      _didDrag = true;
    }

    if (!_didDrag) return;

    final delta = direction * dx / CLToggle.dragWidth;
    final newFraction = (_dragStartFraction + delta).clamp(0.0, 1.0);
    _dragVelocity = direction * event.delta.dx;
    _fractionController.value = newFraction;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.onChanged == null) return;
    _pressController.reverse();

    if (_didDrag) {
      final selected = _currentFraction >= 0.5;
      _dragVelocity = 0;
      _commitSelectedChange(selected);
      _didDrag = false;
    } else {
      _commitSelectedChange(!widget.value);
    }
  }

  void _handleSemanticTap() {
    _commitSelectedChange(!widget.value);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (widget.onChanged == null) return;
    _pressController.reverse();
    _dragVelocity = 0;
    _didDrag = false;
    _animateFractionTo(widget.value ? 1 : 0);
  }

  bool _isLtr(BuildContext context) {
    return Directionality.of(context) != TextDirection.rtl;
  }

  static const SpringDescription _kSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 16,
  );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final accentColor = isLight
        ? const Color(0xFF34C759)
        : const Color(0xFF30D158);
    final trackColor = isLight
        ? const Color(0xFF787878).withValues(alpha: 0.2)
        : const Color(0xFF787880).withValues(alpha: 0.36);

    final animatedTrackColor = Color.lerp(
      trackColor,
      accentColor,
      _currentFraction,
    )!;
    final thumbOffset = _lerpDouble(
      CLToggle.thumbPadding,
      CLToggle.thumbPadding + CLToggle.dragWidth,
      _currentFraction,
    );

    final pressedScale = _lerpDouble(1, 1.5, _pressProgress);
    final velocity = _dragVelocity / 50;
    final velocityScaleX = 1 - (velocity * 0.75).clamp(-0.2, 0.2);
    final velocityScaleY = 1 - (velocity * 0.25).clamp(-0.2, 0.2);
    final thumbScaleX = pressedScale / velocityScaleX;
    final thumbScaleY = pressedScale * velocityScaleY;
    final thumbBlur = _lerpDouble(8, 0, _pressProgress);
    final thumbLensThickness = 10 * _pressProgress;
    final thumbRefractiveIndex = _lerpDouble(1, 1.2, _pressProgress);
    final thumbChromaticAberration = 0.01 * _pressProgress;
    final thumbSurfaceAlpha = _lerpDouble(1, 0, _pressProgress);
    final innerShadowAlpha = _pressProgress;

    return Semantics(
      toggled: widget.value,
      enabled: widget.onChanged != null,
      onTap: widget.onChanged == null ? null : _handleSemanticTap,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: SizedBox(
          width: CLToggle.trackWidth,
          height: CLToggle.trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track
              Container(
                key: _trackKey,
                width: CLToggle.trackWidth,
                height: CLToggle.trackHeight,
                decoration: BoxDecoration(
                  color: animatedTrackColor,
                  borderRadius: BorderRadius.circular(CLToggle.trackHeight / 2),
                ),
              ),
              // Thumb
              Positioned.directional(
                key: _thumbKey,
                start: thumbOffset,
                top: (CLToggle.trackHeight - CLToggle.thumbHeight) / 2,
                width: CLToggle.thumbWidth,
                height: CLToggle.thumbHeight,
                textDirection: Directionality.of(context),
                child: Transform(
                  transform: Matrix4.diagonal3Values(
                    thumbScaleX,
                    thumbScaleY,
                    1,
                  ),
                  alignment: Alignment.center,
                  child: Glass(
                    blur: thumbBlur,
                    thickness: thumbLensThickness,
                    refractiveIndex: thumbRefractiveIndex,
                    chromaticAberration: thumbChromaticAberration,
                    lightIntensity: 0.5 * _pressProgress,
                    ambientStrength: 0.1 * _pressProgress,
                    useRoundedSuperellipse: false,
                    borderRadius: BorderRadius.circular(
                      CLToggle.thumbHeight / 2,
                    ),
                    backgroundColor: Colors.transparent,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 0),
                      ),
                    ],
                    child: CustomPaint(
                      key: _thumbSurfaceKey,
                      size: const Size(
                        CLToggle.thumbWidth,
                        CLToggle.thumbHeight,
                      ),
                      painter: _ThumbSurfacePainter(
                        surfaceAlpha: thumbSurfaceAlpha,
                        innerShadowAlpha: innerShadowAlpha,
                        radius: CLToggle.thumbHeight / 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Draws the Android-equivalent white surface and pressed inner shadow.
class _ThumbSurfacePainter extends CustomPainter {
  final double surfaceAlpha;
  final double innerShadowAlpha;
  final double radius;

  const _ThumbSurfacePainter({
    required this.surfaceAlpha,
    required this.innerShadowAlpha,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (surfaceAlpha > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = Colors.white.withValues(alpha: surfaceAlpha),
      );
    }

    if (innerShadowAlpha <= 0) return;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: innerShadowAlpha * 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 4);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ThumbSurfacePainter oldDelegate) {
    return oldDelegate.surfaceAlpha != surfaceAlpha ||
        oldDelegate.innerShadowAlpha != innerShadowAlpha ||
        oldDelegate.radius != radius;
  }
}
