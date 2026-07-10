import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../surfaces/pressable.dart';
import '../theme/theme.dart';

/// A single Claralight color swatch — the 表盘配色 dots of the design source.
///
/// Circular at rest; the selected swatch stretches into a wide capsule
/// wrapped by a bright ring with a 2px gap, animated with the Claralight
/// spring.
class CLColorSwatchItem extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  /// Diameter of the color fill at rest.
  final double size;

  const CLColorSwatchItem({
    super.key,
    required this.color,
    this.selected = false,
    this.onTap,
    this.size = 23,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    // Ring (2) + gap (2) on each side around the fill.
    final outerHeight = size + 8;
    final outerWidth = selected ? size * 2.6 + 8 : outerHeight;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: CLPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(outerHeight / 2),
        pressedScale: 1.1,
        deformOnDrag: false,
        showHighlight: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: const ElasticOutCurve(1.6),
          width: outerWidth,
          height: outerHeight,
          padding: const EdgeInsets.all(2),
          decoration: clSmoothDecoration(
            color: selected ? theme.colors.control : const Color(0x00000000),
            borderRadius: BorderRadius.circular(outerHeight / 2),
            side: BorderSide(
              color: selected
                  ? theme.colors.textPrimary.withValues(alpha: 0.75)
                  : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: clSmoothDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of selectable [CLColorSwatchItem]s with an optional trailing
/// "add" affordance.
class CLColorSwatchGroup extends StatelessWidget {
  final List<Color> colors;
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;

  /// Called when the trailing "+" swatch is tapped; hidden when null.
  final VoidCallback? onAdd;

  final double swatchSize;
  final double spacing;

  const CLColorSwatchGroup({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onChanged,
    this.onAdd,
    this.swatchSize = 23,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < colors.length; i++)
          CLColorSwatchItem(
            color: colors[i],
            selected: i == selectedIndex,
            size: swatchSize,
            onTap: onChanged == null ? null : () => onChanged!(i),
          ),
        if (onAdd != null)
          CLPressable(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(swatchSize / 2),
            pressedScale: 1.1,
            deformOnDrag: false,
            showHighlight: false,
            child: Container(
              width: swatchSize,
              height: swatchSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colors.control, width: 2),
              ),
              child: Center(
                child: CustomPaint(
                  size: Size.square(swatchSize * 0.55),
                  painter: _PlusPainter(color: theme.colors.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlusPainter extends CustomPainter {
  final Color color;

  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => color != oldDelegate.color;
}
