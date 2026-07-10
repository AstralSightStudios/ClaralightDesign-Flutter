import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A Claralight numeric stepper — the "W 78px ⌃⌄" field of the design
/// source.
///
/// A flat control-fill rounded rectangle with an optional dimmed [prefix]
/// label, the monospace value, an optional [unit], and a stacked
/// caret-up-down column that steps the value.
class CLStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double step;

  /// Dimmed leading label, e.g. "W".
  final String? prefix;

  /// Dimmed trailing unit, e.g. "px".
  final String? unit;

  /// Formats the displayed value. Defaults to trimming trailing zeros.
  final String Function(double value)? format;

  final CLControlSize size;
  final double? width;

  const CLStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1,
    this.prefix,
    this.unit,
    this.format,
    this.size = CLControlSize.small,
    this.width,
  }) : assert(min <= max),
       assert(step > 0);

  @override
  State<CLStepper> createState() => _CLStepperState();
}

class _CLStepperState extends State<CLStepper> {
  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };

  bool get _enabled => widget.onChanged != null;

  String get _display {
    final format = widget.format;
    if (format != null) return format(widget.value);
    final v = widget.value;
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  void _bump(double direction) {
    if (!_enabled) return;
    final next =
        (widget.value + direction * widget.step).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    // Numbers render in the mono family, units in its dimmed regular cut,
    // per the design's value fields.
    final valueStyle = theme.typography.monoStrong.copyWith(
      color: _enabled ? colors.textPrimary : colors.textDisabled,
    );
    final unitStyle = theme.typography.mono.copyWith(
      color: _enabled ? colors.textTertiary : colors.textDisabled,
    );
    final prefixStyle = theme.typography.callout.copyWith(
      fontWeight: FontWeight.w400,
      color: _enabled ? colors.textTertiary : colors.textDisabled,
    );

    return SizedBox(
      width: widget.width,
      height: _height,
      child: DecoratedBox(
        decoration: clSmoothDecoration(
          color: _enabled
              ? colors.control
              : colors.control.withValues(alpha: colors.control.a * 0.5),
          borderRadius: BorderRadius.circular(theme.radii.control),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.size == CLControlSize.small ? 10 : 12,
            right: 6,
          ),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                Text(widget.prefix!, style: prefixStyle),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: _display,
                    style: valueStyle,
                    children: [
                      if (widget.unit != null)
                        TextSpan(text: widget.unit, style: unitStyle),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Stacked caret-up-down, like the design's CaretUpDown glyph.
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChevronButton(
                    up: true,
                    enabled: _enabled && widget.value < widget.max,
                    onTap: () => _bump(1),
                  ),
                  _ChevronButton(
                    up: false,
                    enabled: _enabled && widget.value > widget.min,
                    onTap: () => _bump(-1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatefulWidget {
  final bool up;
  final bool enabled;
  final VoidCallback onTap;

  const _ChevronButton({
    required this.up,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ChevronButton> createState() => _ChevronButtonState();
}

class _ChevronButtonState extends State<_ChevronButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = CLTheme.of(context).colors;
    final color = widget.enabled
        ? (_hovered ? colors.textPrimary : colors.textSecondary)
        : colors.textDisabled;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: 18,
          height: 10,
          child: Center(
            child: CustomPaint(
              size: const Size(8, 4.5),
              painter: _StepChevronPainter(color: color, up: widget.up),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepChevronPainter extends CustomPainter {
  final Color color;
  final bool up;

  const _StepChevronPainter({required this.color, required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = up
        ? (Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height))
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StepChevronPainter oldDelegate) =>
      color != oldDelegate.color || up != oldDelegate.up;
}
