import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../scrolling/cl_list.dart';
import '../scrolling/types.dart';
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

/// A horizontal row of selectable [CLColorSwatchItem]s.
class CLColorSwatchGroup extends StatefulWidget {
  final List<Color> colors;
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;
  final double swatchSize;
  final double spacing;

  const CLColorSwatchGroup({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onChanged,
    this.swatchSize = 23,
    this.spacing = 8,
  });

  @override
  State<CLColorSwatchGroup> createState() => _CLColorSwatchGroupState();
}

class _CLColorSwatchGroupState extends State<CLColorSwatchGroup> {
  static const _scrollDuration = Duration(milliseconds: 320);
  static const _offsetTolerance = 0.01;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleSelectedReveal(Duration.zero);
  }

  @override
  void didUpdateWidget(covariant CLColorSwatchGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scheduleSelectedReveal(_scrollDuration);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSelectedReveal(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _revealSelected(duration);
    });
  }

  void _revealSelected(Duration duration) {
    final index = widget.selectedIndex;
    if (index == null || index < 0 || index >= widget.colors.length) return;

    final position = _controller.position;
    final itemWidth = widget.swatchSize + 8;
    final selectedWidth = widget.swatchSize * 2.6 + 8;
    final selectedStart = index * (itemWidth + widget.spacing);
    final selectedEnd = selectedStart + selectedWidth;
    final visibleStart = position.pixels;
    final visibleEnd = visibleStart + position.viewportDimension;

    var target = visibleStart;
    if (selectedStart < visibleStart) {
      target = selectedStart;
    } else if (selectedEnd > visibleEnd) {
      target = selectedEnd - position.viewportDimension;
    }

    final contentWidth =
        widget.colors.length * itemWidth +
        (selectedWidth - itemWidth) +
        (widget.colors.length > 1
            ? (widget.colors.length - 1) * widget.spacing
            : 0);
    final maxOffset = (contentWidth - position.viewportDimension).clamp(
      0.0,
      double.infinity,
    );
    target = target.clamp(0.0, maxOffset);

    if ((target - visibleStart).abs() < _offsetTolerance) return;
    if (duration == Duration.zero) {
      position.jumpTo(target);
      return;
    }

    final reachableTarget = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position
        .animateTo(
          reachableTarget,
          duration: duration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted && widget.selectedIndex == index) {
            _scheduleSelectedReveal(Duration.zero);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.swatchSize + 8,
      child: CLList.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        scrollbarVisibility: CLScrollbarVisibility.hidden,
        itemCount: widget.colors.length,
        separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
        itemBuilder: (context, index) {
          return Align(
            child: CLColorSwatchItem(
              color: widget.colors[index],
              selected: index == widget.selectedIndex,
              size: widget.swatchSize,
              onTap: widget.onChanged == null
                  ? null
                  : () => widget.onChanged!(index),
            ),
          );
        },
      ),
    );
  }
}
