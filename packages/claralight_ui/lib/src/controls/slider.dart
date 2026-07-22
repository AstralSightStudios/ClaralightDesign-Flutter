import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A Claralight slider.
///
/// Recessed capsule track, accent-filled progress, white round thumb that
/// swells under the finger with the Claralight spring.
class CLSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;

  /// Fill color of the active track. Defaults to the theme accent.
  final Color? activeColor;

  const CLSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.activeColor,
  }) : assert(min < max);

  static const double trackHeight = 6;
  static const double thumbSize = 18;
  static const double hitHeight = 32;

  @override
  State<CLSlider> createState() => _CLSliderState();
}

class _CLSliderState extends State<CLSlider> with TickerProviderStateMixin {
  static const _pressSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 18,
  );

  static SpringDescription _visualSpringFor(double distance) {
    final dampingProgress = (distance / 0.35).clamp(0.0, 1.0);
    return SpringDescription(
      mass: 1,
      stiffness: 520,
      // Small corrections retain a light spring. Large jumps approach
      // critical damping so their rebound does not scale with the distance.
      damping: 24 + 24 * dampingProgress,
    );
  }

  late final AnimationController _press;

  /// Animated track fraction. Follows the finger 1:1 while dragging and
  /// springs to the new position when the value jumps (track taps,
  /// programmatic changes).
  late final AnimationController _visual;

  /// Whether the pointer is actively tracking (drag) — jumps skip the
  /// spring so the thumb never lags behind the finger.
  bool _tracking = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}));
    _visual = AnimationController.unbounded(value: _fraction, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) _snapReducedMotionGeometry();
  }

  void _snapReducedMotionGeometry() {
    _press.stop();
    _visual.stop();
    _press.value = 0;
    _visual.value = _fraction;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CLSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _fraction;
    if (_disableAnimations || _tracking) {
      _visual.stop();
      _visual.value = target;
    } else if ((target - _visual.value).abs() > 0.0005) {
      final distance = (target - _visual.value).abs();
      _visual.animateWith(
        SpringSimulation(
          _visualSpringFor(distance),
          _visual.value,
          target,
          0,
          tolerance: Tolerance.defaultTolerance,
        ),
      );
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _visual.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  void _update(Offset localPosition, double width) {
    if (!_enabled) return;
    final usable = width - CLSlider.thumbSize;
    final fraction = ((localPosition.dx - CLSlider.thumbSize / 2) / usable)
        .clamp(0.0, 1.0);
    widget.onChanged!(widget.min + fraction * (widget.max - widget.min));
  }

  void _setPressed(bool pressed, {bool tracking = false}) {
    _tracking = pressed && tracking;
    if (_disableAnimations) {
      _press.stop();
      _press.value = 0;
      return;
    }
    if (pressed) {
      _press.animateTo(
        1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    } else {
      _press.animateWith(
        SpringSimulation(
          _pressSpring,
          _press.value,
          0,
          0,
          tolerance: Tolerance.defaultTolerance,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    var active = widget.activeColor ?? theme.colors.accent;
    var thumb = const Color(0xFFFFFFFF);
    if (!_enabled) {
      active = active.withValues(alpha: active.a * 0.45);
      thumb = thumb.withValues(alpha: 0.7);
    }

    final pressScale = 1 + 0.25 * _press.value.clamp(0.0, 1.5);

    return Semantics(
      slider: true,
      enabled: _enabled,
      value: widget.value.toStringAsFixed(2),
      child: SizedBox(
        height: CLSlider.hitHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final usable = width - CLSlider.thumbSize;
            final thumbLeft = usable * _visual.value.clamp(0.0, 1.0);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Track taps spring the thumb to the new position; drags
              // keep it glued to the finger.
              onTapDown: (d) {
                _setPressed(true);
                _update(d.localPosition, width);
              },
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onHorizontalDragStart: (d) {
                _setPressed(true, tracking: true);
                _update(d.localPosition, width);
              },
              onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
              onHorizontalDragEnd: (_) => _setPressed(false),
              onHorizontalDragCancel: () {
                if (_tracking) _setPressed(false);
              },
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Recessed track.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (CLSlider.hitHeight - CLSlider.trackHeight) / 2,
                    height: CLSlider.trackHeight,
                    child: DecoratedBox(
                      decoration: clSmoothDecoration(
                        color: theme.colors.track,
                        borderRadius: BorderRadius.circular(
                          CLSlider.trackHeight / 2,
                        ),
                      ),
                    ),
                  ),
                  // Active fill.
                  Positioned(
                    left: 0,
                    top: (CLSlider.hitHeight - CLSlider.trackHeight) / 2,
                    height: CLSlider.trackHeight,
                    width: thumbLeft + CLSlider.thumbSize / 2,
                    child: DecoratedBox(
                      decoration: clSmoothDecoration(
                        color: active,
                        borderRadius: BorderRadius.circular(
                          CLSlider.trackHeight / 2,
                        ),
                      ),
                    ),
                  ),
                  // Thumb.
                  Positioned(
                    left: thumbLeft,
                    top: (CLSlider.hitHeight - CLSlider.thumbSize) / 2,
                    width: CLSlider.thumbSize,
                    height: CLSlider.thumbSize,
                    child: Transform.scale(
                      scale: pressScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumb,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
