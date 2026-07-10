import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A Claralight toggle switch.
///
/// The track is a 48x24 outlined capsule; the wide 28x20 white thumb can be
/// tapped or dragged, with the springy Claralight overshoot on release.
/// Geometry and fills follow the ClaraLight design source.
class CLToggle extends StatefulWidget {
  /// Whether the switch is currently on.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool>? onChanged;

  /// Track color while on. Defaults to the theme success green.
  final Color? activeColor;

  const CLToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  /// Track width in logical pixels.
  static const double trackWidth = 48;

  /// Track height in logical pixels.
  static const double trackHeight = 24;

  /// Thumb width in logical pixels.
  static const double thumbWidth = 28;

  /// Thumb height in logical pixels.
  static const double thumbHeight = 20;

  /// Horizontal padding between the track edges and the thumb travel bounds.
  static const double thumbPadding = 2;

  /// Horizontal distance the thumb travels between on/off states.
  static const double dragWidth =
      trackWidth - thumbWidth - 2 * thumbPadding;

  @override
  State<CLToggle> createState() => _CLToggleState();
}

class _CLToggleState extends State<CLToggle> with TickerProviderStateMixin {
  static const Key _trackKey = Key('cl-toggle-track');
  static const Key _thumbKey = Key('cl-toggle-thumb');

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
    final theme = CLTheme.of(context);
    final enabled = widget.onChanged != null;

    final activeColor = widget.activeColor ?? theme.colors.success;
    final inactiveColor = theme.colors.controlHighlight;
    var trackColor = Color.lerp(inactiveColor, activeColor, _currentFraction)!;
    if (!enabled) trackColor = trackColor.withValues(alpha: trackColor.a * 0.5);

    final thumbOffset = _lerpDouble(
      CLToggle.thumbPadding,
      CLToggle.thumbPadding + CLToggle.dragWidth,
      _currentFraction,
    );

    final pressedScale = _lerpDouble(1, 1.12, _pressProgress);
    final velocity = _dragVelocity / 50;
    final velocityScaleX = 1 - (velocity * 0.75).clamp(-0.2, 0.2);
    final velocityScaleY = 1 - (velocity * 0.25).clamp(-0.2, 0.2);
    final thumbScaleX = pressedScale / velocityScaleX;
    final thumbScaleY = pressedScale * velocityScaleY;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _handleSemanticTap : null,
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
                decoration: clSmoothDecoration(
                  color: trackColor,
                  borderRadius:
                      BorderRadius.circular(CLToggle.trackHeight / 2),
                  side: BorderSide(color: theme.colors.outline),
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
                  child: _buildThumb(enabled),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(bool enabled) {
    // The design's resting thumb is 70% white; it solidifies as the
    // toggle turns on. Disabled thumbs stay dimmer.
    final alpha = enabled ? _lerpDouble(0.7, 1, _currentFraction) : 0.45;
    return DecoratedBox(
      decoration: clSmoothDecoration(
        color: Color.fromRGBO(255, 255, 255, alpha),
        borderRadius: BorderRadius.circular(CLToggle.thumbHeight / 2),
        shadows: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
