import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A Claralight linear progress bar.
///
/// Recessed capsule track with an accent fill that animates smoothly
/// between values. Pass a null [value] for an indeterminate sweep.
class CLProgressBar extends StatefulWidget {
  /// Progress 0..1, or null for indeterminate.
  final double? value;

  /// Fill color. Defaults to the theme accent.
  final Color? color;

  final double height;

  const CLProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  @override
  State<CLProgressBar> createState() => _CLProgressBarState();
}

class _CLProgressBarState extends State<CLProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncSweep();
  }

  @override
  void didUpdateWidget(CLProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  void _syncSweep() {
    if (widget.value == null) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else if (_sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final fillColor = widget.color ?? theme.colors.accent;
    final radius = BorderRadius.circular(widget.height / 2);

    return Semantics(
      value: widget.value == null
          ? null
          : '${(widget.value! * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: clSmoothDecoration(
            color: theme.colors.track,
            borderRadius: radius,
          ),
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: widget.value != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      widthFactor: widget.value!.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: clSmoothDecoration(
                          color: fillColor,
                          borderRadius: radius,
                        ),
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _SweepPainter(
                          t: _sweep.value,
                          color: fillColor,
                          radius: widget.height / 2,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double t;
  final Color color;
  final double radius;

  const _SweepPainter({
    required this.t,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeInOutCubic.transform(t);
    final barWidth = size.width * 0.32;
    final travel = size.width + barWidth;
    final left = eased * travel - barWidth;

    // Soft leading/trailing fade so the sweep reads as light, not a block.
    final rect = Rect.fromLTWH(left, 0, barWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color,
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.25, 0.75, 1],
      ).createShader(rect);

    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      t != oldDelegate.t || color != oldDelegate.color;
}

/// A Claralight circular progress ring.
class CLProgressRing extends StatelessWidget {
  /// Progress 0..1.
  final double value;

  final double size;
  final double strokeWidth;

  /// Ring color. Defaults to the theme accent.
  final Color? color;

  /// Optional centered child (e.g. a percentage label).
  final Widget? child;

  const CLProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.strokeWidth = 4,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return CustomPaint(
            painter: _RingPainter(
              value: animated,
              trackColor: theme.colors.track,
              color: color ?? theme.colors.accent,
              strokeWidth: strokeWidth,
            ),
            child: Center(child: child),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color color;
  final double strokeWidth;

  const _RingPainter({
    required this.value,
    required this.trackColor,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      value != oldDelegate.value ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor;
}
