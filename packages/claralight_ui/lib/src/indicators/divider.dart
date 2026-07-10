import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A Claralight hairline divider, solid or [dashed].
///
/// The design source separates groups with solid hairlines and closely
/// related rows with dashed ones.
class CLDivider extends StatelessWidget {
  /// Vertical space the divider occupies.
  final double height;

  /// Indent on the leading/trailing edges.
  final double indent;

  /// Draws the hairline as 4/4 dashes instead of a solid line.
  final bool dashed;

  const CLDivider({
    super.key,
    this.height = 17,
    this.indent = 0,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = CLTheme.of(context).colors.separator;
    return SizedBox(
      height: height,
      child: Center(
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: indent, end: indent),
          child: SizedBox(
            height: 1,
            width: double.infinity,
            child: dashed
                ? CustomPaint(painter: _DashPainter(color: color))
                : ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.butt;
    const dash = 4.0;
    const gap = 4.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}
