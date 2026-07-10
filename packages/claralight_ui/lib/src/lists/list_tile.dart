import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../surfaces/pressable.dart';
import '../theme/theme.dart';

/// A Claralight list row — the "样式 1 / 样式 2" and layer-tree rows of the
/// design source.
///
/// Flat by default, [selected] rows fill with a control layer. Supports a
/// [leading] icon, [trailing] widget, tree [depth] indentation, an
/// [expanded] disclosure chevron for tree lists, and an [outlined] variant
/// for add-item rows ("新增样式").
class CLListTile extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final CLControlSize size;

  /// Tree indentation level; each level indents by 16.
  final int depth;

  /// Renders the row as a 2px-outlined hint row instead of a filled one —
  /// the "新增样式 / 新建表盘" add rows of the design.
  final bool outlined;

  /// Non-null renders a disclosure chevron: `true` pointing down,
  /// `false` pointing right. [onExpandedChanged] toggles it.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  const CLListTile({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.selected = false,
    this.size = CLControlSize.medium,
    this.depth = 0,
    this.outlined = false,
    this.expanded,
    this.onExpandedChanged,
  }) : assert(depth >= 0);

  @override
  State<CLListTile> createState() => _CLListTileState();
}

class _CLListTileState extends State<CLListTile> {
  bool _hovered = false;

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 40,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final radius = BorderRadius.circular(theme.radii.control);
    final interactive = widget.onTap != null;

    final fill = widget.outlined
        ? const Color(0x00000000)
        : widget.selected
            ? colors.control
            : _hovered && interactive
                ? colors.controlHighlight
                : const Color(0x00000000);
    final side = widget.outlined
        ? BorderSide(color: colors.control, width: 2)
        : BorderSide.none;

    final textStyle = (widget.size == CLControlSize.large
            ? theme.typography.body
            : theme.typography.callout.withCLWeight(FontWeight.w500))
        .copyWith(
      color: widget.outlined
          ? colors.textHint
          : widget.selected
              ? colors.textPrimary
              : colors.textSecondary,
    );

    return Semantics(
      button: interactive,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: CLPressable(
          onTap: widget.onTap,
          borderRadius: radius,
          pressedScale: 1.015,
          deformOnDrag: false,
          showHighlight: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: _height,
            padding: EdgeInsets.only(
              left: 8.0 + widget.depth * 16.0,
              right: 8,
            ),
            decoration: clSmoothDecoration(
              color: fill,
              borderRadius: radius,
              side: side,
            ),
            child: Row(
              children: [
                if (widget.expanded != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onExpandedChanged == null
                        ? null
                        : () => widget.onExpandedChanged!(!widget.expanded!),
                    child: SizedBox(
                      width: 20,
                      height: _height,
                      child: Center(
                        child: AnimatedRotation(
                          duration: const Duration(milliseconds: 160),
                          turns: widget.expanded! ? 0.25 : 0,
                          child: CustomPaint(
                            size: const Size(6, 10),
                            painter: _DisclosurePainter(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      size: widget.size == CLControlSize.small ? 14 : 18,
                      color: widget.outlined
                          ? colors.textHint
                          : widget.selected
                              ? colors.textPrimary
                              : colors.textSecondary,
                    ),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  IconTheme.merge(
                    data: IconThemeData(
                      size: widget.size == CLControlSize.small ? 14 : 17,
                      color: colors.textSecondary,
                    ),
                    child: widget.trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A vertical group of [CLListTile]s with an optional header, matching the
/// mockup's section blocks.
class CLListSection extends StatelessWidget {
  /// Optional dimmed header above the rows.
  final String? header;

  /// Optional trailing widget on the header row.
  final Widget? headerTrailing;

  final List<Widget> children;
  final double spacing;

  const CLListSection({
    super.key,
    this.header,
    this.headerTrailing,
    required this.children,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    header!,
                    style: theme.typography.label
                        .copyWith(color: theme.colors.textHint),
                  ),
                ),
                ?headerTrailing,
              ],
            ),
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}

class _DisclosurePainter extends CustomPainter {
  final Color color;

  const _DisclosurePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DisclosurePainter oldDelegate) =>
      color != oldDelegate.color;
}
