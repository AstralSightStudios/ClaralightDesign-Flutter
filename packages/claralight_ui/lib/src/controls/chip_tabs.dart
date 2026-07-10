import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../surfaces/pressable.dart';
import '../theme/theme.dart';

/// The ClaraLight chip tab row — the "时间日期 / 运动健康 / 工具数据"
/// filter of the design source.
///
/// A row of small rounded chips; the selected one raises with a control
/// fill. Unlike [CLSegmentedControl] the chips hug their labels and the
/// row can scroll or wrap freely.
class CLChipTabs extends StatelessWidget {
  /// Chip labels, in order.
  final List<String> tabs;

  /// Index of the selected chip.
  final int selectedIndex;

  /// Called with the tapped chip index.
  final ValueChanged<int>? onChanged;

  /// Gap between chips.
  final double spacing;

  const CLChipTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.spacing = 4,
  }) : assert(tabs.length > 0);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (var i = 0; i < tabs.length; i++)
          _Chip(
            label: tabs[i],
            selected: i == selectedIndex,
            enabled: onChanged != null,
            onTap: onChanged == null ? null : () => onChanged!(i),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final radius = BorderRadius.circular(theme.radii.control);

    final color = !enabled
        ? colors.textDisabled
        : selected
            ? colors.textSecondary
            : colors.textHint;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CLPressable(
        onTap: onTap,
        borderRadius: radius,
        pressedScale: 1.04,
        deformOnDrag: false,
        showHighlight: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: clSmoothDecoration(
            color: selected ? colors.control : const Color(0x00000000),
            borderRadius: radius,
          ),
          child: Center(
            widthFactor: 1,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              style: theme.typography.callout.copyWith(color: color),
              child: Text(label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}
