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

  /// Optional row shape. Defaults to the theme's control radius.
  ///
  /// Directional radii are resolved against the ambient text direction.
  final BorderRadiusGeometry? borderRadius;

  /// Optional color for the label and leading icon.
  final Color? tint;

  final CLControlSize size;

  /// Maximum lines for the default label. `null` allows the row to grow with
  /// all wrapped lines while preserving the control size as its minimum height.
  final int? labelMaxLines;

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
    this.borderRadius,
    this.tint,
    this.size = CLControlSize.medium,
    this.labelMaxLines = 1,
    this.depth = 0,
    this.outlined = false,
    this.expanded,
    this.onExpandedChanged,
    this.disclosureAnimationDuration = CLMotion.standard,
  }) : assert(depth >= 0),
       assert(labelMaxLines == null || labelMaxLines > 0);

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
    final visuals = _resolveVisuals(context);
    return Semantics(
      button: visuals.interactive,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: visuals.interactive
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: _buildPressable(context, visuals),
      ),
    );
  }

  _ListTileVisuals _resolveVisuals(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final radius =
        (widget.borderRadius ?? BorderRadius.circular(theme.radii.control))
            .resolve(Directionality.of(context));
    final interactive = widget.onTap != null;
    final fill = widget.outlined
        ? const Color(0x00000000)
        : widget.selected
        ? colors.control
        : _hovered && interactive
        ? colors.controlHighlight
        : const Color(0x00000000);
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

    return _ListTileVisuals(
      theme: theme,
      radius: radius,
      interactive: interactive,
      fill: fill,
      side: widget.outlined
          ? BorderSide(color: colors.control, width: 2)
          : BorderSide.none,
      leadingColor: leadingColor,
      textStyle: textStyle,
      multiline: widget.labelMaxLines != 1,
    );
  }

  Widget _buildPressable(BuildContext context, _ListTileVisuals visuals) {
    return CLPressable(
      onTap: widget.onTap,
      borderRadius: visuals.radius,
      pressedScale: 1.015,
      deformOnDrag: false,
      showHighlight: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: visuals.multiline ? null : _height,
        constraints: visuals.multiline
            ? BoxConstraints(minHeight: _height)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: visuals.multiline ? 7 : 0,
        ),
        decoration: clSmoothDecoration(
          color: visuals.fill,
          borderRadius: visuals.radius,
          side: visuals.side,
        ),
        child: _buildRow(context, visuals),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _ListTileVisuals visuals) {
    return Row(
      children: [
        ..._buildDepthGuides(visuals),
        if (widget.leading != null) ..._buildLeading(visuals),
        Expanded(child: _buildLabel(context, visuals)),
        if (widget.trailing != null) ..._buildTrailing(visuals),
        if (widget.expanded != null) ..._buildDisclosure(visuals),
      ],
    );
  }

  List<Widget> _buildDepthGuides(_ListTileVisuals visuals) {
    return [
      for (var i = 0; i < widget.depth; i++) ...[
        SizedBox(
          width: 14,
          height: 18,
          child: CustomPaint(
            painter: _DepthGuidePainter(
              color: visuals.theme.colors.textPrimary.withValues(alpha: 0.18),
              rowHeight: _height,
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
    ];
  }

  List<Widget> _buildLeading(_ListTileVisuals visuals) {
    return [
      IconTheme.merge(
        data: IconThemeData(
          size: widget.size == CLControlSize.small ? 14 : 18,
          color: visuals.leadingColor,
        ),
        child: widget.leading!,
      ),
      const SizedBox(width: 10),
    ];
  }

  Widget _buildLabel(BuildContext context, _ListTileVisuals visuals) {
    final labelBuilder = widget.labelBuilder;
    if (labelBuilder != null) {
      return ExcludeSemantics(child: labelBuilder(context, visuals.textStyle));
    }
    return Text(
      widget.label,
      maxLines: widget.labelMaxLines,
      overflow: visuals.multiline ? TextOverflow.clip : TextOverflow.ellipsis,
      style: visuals.textStyle,
    );
  }

  List<Widget> _buildTrailing(_ListTileVisuals visuals) {
    return [
      const SizedBox(width: 10),
      IconTheme.merge(
        data: IconThemeData(
          size: widget.size == CLControlSize.small ? 14 : 17,
          color: visuals.theme.colors.textSecondary,
        ),
        child: widget.trailing!,
      ),
    ];
  }

  List<Widget> _buildDisclosure(_ListTileVisuals visuals) {
    return [
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
                painter: _DisclosurePainter(
                  color: visuals.theme.colors.textHint,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _ListTileVisuals {
  const _ListTileVisuals({
    required this.theme,
    required this.radius,
    required this.interactive,
    required this.fill,
    required this.side,
    required this.leadingColor,
    required this.textStyle,
    required this.multiline,
  });

  final CLThemeData theme;
  final BorderRadius radius;
  final bool interactive;
  final Color fill;
  final BorderSide side;
  final Color leadingColor;
  final TextStyle textStyle;
  final bool multiline;
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
  ScrollController? _ownedController;

  ScrollController get _effectiveController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _ownedController = widget.controller == null ? ScrollController() : null;
  }

  @override
  void didUpdateWidget(CLTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _ownedController?.dispose();
    _ownedController = widget.controller == null ? ScrollController() : null;
  }

  @override
  void dispose() {
    _ownedController?.dispose();
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
          controller: _effectiveController,
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
