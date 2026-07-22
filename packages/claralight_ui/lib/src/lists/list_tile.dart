import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../scrolling/cl_list.dart';
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

  /// Optional label content built with the tile's resolved text style.
  ///
  /// [label] remains the accessibility label when this is provided.
  final Widget Function(BuildContext context, TextStyle style)? labelBuilder;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;

  /// Optional color for the label and leading icon.
  final Color? tint;

  final CLControlSize size;

  /// Tree indentation level. Each level adds a 14px guide and a 10px gap.
  final int depth;

  /// Renders the row as a 2px-outlined hint row instead of a filled one —
  /// the "新增样式 / 新建表盘" add rows of the design.
  final bool outlined;

  /// Non-null renders a disclosure chevron: `true` pointing up,
  /// `false` pointing down. [onExpandedChanged] toggles it.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Duration of the disclosure rotation. Dense, frequently operated trees
  /// may use [Duration.zero] for immediate feedback.
  final Duration disclosureAnimationDuration;

  const CLListTile({
    super.key,
    required this.label,
    this.labelBuilder,
    this.onTap,
    this.leading,
    this.trailing,
    this.selected = false,
    this.tint,
    this.size = CLControlSize.medium,
    this.depth = 0,
    this.outlined = false,
    this.expanded,
    this.onExpandedChanged,
    this.disclosureAnimationDuration = CLMotion.standard,
  }) : assert(depth >= 0);

  @override
  State<CLListTile> createState() => _CLListTileState();
}

class _CLListTileState extends State<CLListTile> {
  bool _hovered = false;

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 35,
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

    final labelColor =
        widget.tint ??
        (widget.outlined ? colors.textHint : colors.textSecondary);
    final leadingColor =
        widget.tint ?? (widget.outlined ? colors.textHint : colors.textPrimary);
    final textStyle =
        (widget.size == CLControlSize.large
                ? theme.typography.body
                : theme.typography.callout.withCLWeight(FontWeight.w400))
            .copyWith(color: labelColor);

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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: clSmoothDecoration(
              color: fill,
              borderRadius: radius,
              side: side,
            ),
            child: Row(
              children: [
                for (var i = 0; i < widget.depth; i++) ...[
                  SizedBox(
                    width: 14,
                    height: 18,
                    child: CustomPaint(
                      painter: _DepthGuidePainter(
                        color: colors.textPrimary.withValues(alpha: 0.18),
                        rowHeight: _height,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (widget.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      size: widget.size == CLControlSize.small ? 14 : 18,
                      color: leadingColor,
                    ),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: widget.labelBuilder == null
                      ? Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle,
                        )
                      : ExcludeSemantics(
                          child: widget.labelBuilder!(context, textStyle),
                        ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 10),
                  IconTheme.merge(
                    data: IconThemeData(
                      size: widget.size == CLControlSize.small ? 14 : 17,
                      color: colors.textSecondary,
                    ),
                    child: widget.trailing!,
                  ),
                ],
                if (widget.expanded != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onExpandedChanged == null
                        ? null
                        : () => widget.onExpandedChanged!(!widget.expanded!),
                    child: SizedBox.square(
                      dimension: 16,
                      child: Center(
                        child: AnimatedRotation(
                          duration: widget.disclosureAnimationDuration,
                          turns: widget.expanded! ? 0.5 : 0,
                          child: CustomPaint(
                            size: const Size(11.5, 6.5),
                            painter: _DisclosurePainter(color: colors.textHint),
                          ),
                        ),
                      ),
                    ),
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
                    style: theme.typography.label.copyWith(
                      color: theme.colors.textHint,
                    ),
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

/// A progressively blurred layer tree with the spacing, viewport padding, and
/// automatic scrollbar treatment from the ClaraLight design source.
///
/// The parent must provide a bounded height. Use [CLListTile.depth] to encode
/// nesting and [CLListTile.expanded] for disclosure controls.
class CLTreeView extends StatefulWidget {
  /// Usually [CLListTile]s, or composed widgets that group related tree rows.
  final List<Widget> children;
  final ScrollController? controller;

  const CLTreeView({super.key, required this.children, this.controller});

  @override
  State<CLTreeView> createState() => _CLTreeViewState();
}

class _CLTreeViewState extends State<CLTreeView> {
  late ScrollController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(CLTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    if (_ownsController) _controller.dispose();
    _setController(widget.controller);
  }

  void _setController(ScrollController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'CLTreeView requires a bounded height.',
        );
        return CLList.separated(
          controller: _controller,
          padding: const EdgeInsets.only(top: 4, right: 10, bottom: 4),
          itemCount: widget.children.length,
          itemBuilder: (context, index) => widget.children[index],
          separatorBuilder: (context, index) => const SizedBox(height: 4),
        );
      },
    );
  }
}

class _DepthGuidePainter extends CustomPainter {
  final Color color;
  final double rowHeight;

  const _DepthGuidePainter({required this.color, required this.rowHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final overhang = (rowHeight - size.height) / 2 + 2;
    canvas.drawLine(
      Offset(size.width - 5, -overhang),
      Offset(size.width - 5, size.height + overhang),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DepthGuidePainter oldDelegate) =>
      color != oldDelegate.color || rowHeight != oldDelegate.rowHeight;
}

class _DisclosurePainter extends CustomPainter {
  final Color color;

  const _DisclosurePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(0, 0.5)
        ..lineTo(size.width / 2, size.height - 0.5)
        ..lineTo(size.width, 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DisclosurePainter oldDelegate) =>
      color != oldDelegate.color;
}
