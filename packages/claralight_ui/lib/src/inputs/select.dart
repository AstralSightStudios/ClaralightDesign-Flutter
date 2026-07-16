import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../scrolling/cl_list.dart';
import '../surfaces/pressable.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// One option of a [CLSelect].
class CLSelectOption<T> {
  final T value;
  final String label;

  const CLSelectOption(this.value, this.label);
}

/// A Claralight dropdown — the "填充模式 / 数字填充" and "格式 / 00:00"
/// fields of the desktop mockup.
///
/// A control-fill rounded rectangle showing the selected label and a
/// chevron; tapping pops a flat options panel that springs open below or
/// above the field.
class CLSelect<T> extends StatefulWidget {
  final List<CLSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final CLControlSize size;
  final double? width;

  /// Whether the selected option is centered over the trigger when opened.
  ///
  /// When false, the panel opens below the trigger, or above it when there is
  /// not enough room below.
  final bool alignSelectedOption;

  /// Overrides the trigger's corner radius. Pass [BorderRadius.zero] when
  /// the field is a cell of a grouped grid whose outer clip owns the corner
  /// rounding; null keeps the standalone control radius. The options panel
  /// is unaffected.
  final BorderRadius? borderRadius;

  const CLSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.size = CLControlSize.large,
    this.width,
    this.alignSelectedOption = true,
    this.borderRadius,
  }) : assert(options.length > 0);

  @override
  State<CLSelect<T>> createState() => _CLSelectState<T>();
}

class _CLSelectState<T> extends State<CLSelect<T>>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  late final AnimationController _reveal;

  bool _open = false;
  bool _hovered = false;
  ScrollController? _scrollController;
  Offset _panelOffset = Offset.zero;
  double _panelWidth = 0;
  double _panelHeight = 0;
  AlignmentGeometry _revealAlignment = Alignment.topCenter;

  static const double _panelPadding = 6;
  static const double _panelHorizontalPadding = 6;
  static const double _panelOutlineWidth = 1;
  static const double _screenMargin = 8;
  static const double _fieldGap = 4;

  @override
  void initState() {
    super.initState();
    _reveal =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
          reverseDuration: const Duration(milliseconds: 140),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            _portal.hide();
            _scrollController?.dispose();
            _scrollController = null;
            if (mounted) setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _reveal.dispose();
    super.dispose();
  }

  double get _height => widget.size.controlHeight;

  double get _rowHeight => _height;

  bool get _enabled => widget.onChanged != null;

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openPanel();
    }
  }

  void _openPanel() {
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final fieldBox = context.findRenderObject()! as RenderBox;
    final origin = fieldBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final mediaPadding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final safeLeft = mediaPadding.left + _screenMargin;
    final safeTop = mediaPadding.top + _screenMargin;
    final safeRight =
        overlayBox.size.width - mediaPadding.right - _screenMargin;
    final safeBottom =
        overlayBox.size.height - mediaPadding.bottom - _screenMargin;
    final availableWidth = math.max(0.0, safeRight - safeLeft);
    final availableHeight = math.max(0.0, safeBottom - safeTop);
    final listContentHeight =
        widget.options.length * _rowHeight + _panelPadding * 2;
    final panelContentHeight = listContentHeight + _panelOutlineWidth * 2;
    final selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.value,
    );
    final fieldCenterY = origin.dy + fieldBox.size.height / 2;

    _panelWidth = math.min(
      fieldBox.size.width +
          _panelHorizontalPadding * 2 +
          _panelOutlineWidth * 2,
      availableWidth,
    );
    final desiredPanelLeft =
        origin.dx - _panelHorizontalPadding - _panelOutlineWidth;
    final panelLeft = desiredPanelLeft.clamp(
      safeLeft,
      math.max(safeLeft, safeRight - _panelWidth),
    );

    double panelTop;
    double initialScrollOffset = 0;
    if (widget.alignSelectedOption && selectedIndex >= 0) {
      _panelHeight = math.min(panelContentHeight, availableHeight);
      final selectedPanelCenter =
          _panelOutlineWidth +
          _panelPadding +
          selectedIndex * _rowHeight +
          _rowHeight / 2;
      final desiredTop = fieldCenterY - selectedPanelCenter;
      panelTop = desiredTop.clamp(
        safeTop,
        math.max(safeTop, safeBottom - _panelHeight),
      );
      final listViewportHeight = math.max(
        0.0,
        _panelHeight - _panelOutlineWidth * 2,
      );
      final maxScrollOffset = math.max(
        0.0,
        listContentHeight - listViewportHeight,
      );
      initialScrollOffset = (panelTop + selectedPanelCenter - fieldCenterY)
          .clamp(0.0, maxScrollOffset);
      final selectedViewportCenter = selectedPanelCenter - initialScrollOffset;
      final revealY = _panelHeight == 0
          ? 0.5
          : (selectedViewportCenter / _panelHeight).clamp(0.0, 1.0);
      _revealAlignment = FractionalOffset(0.5, revealY);
    } else {
      final spaceBelow = math.max(
        0.0,
        safeBottom - (origin.dy + fieldBox.size.height + _fieldGap),
      );
      final spaceAbove = math.max(0.0, origin.dy - _fieldGap - safeTop);
      final dropUp = panelContentHeight > spaceBelow && spaceAbove > spaceBelow;
      _panelHeight = math.min(
        panelContentHeight,
        dropUp ? spaceAbove : spaceBelow,
      );
      panelTop = dropUp
          ? origin.dy - _fieldGap - _panelHeight
          : origin.dy + fieldBox.size.height + _fieldGap;
      panelTop = panelTop.clamp(
        safeTop,
        math.max(safeTop, safeBottom - _panelHeight),
      );
      _revealAlignment = dropUp ? Alignment.bottomCenter : Alignment.topCenter;
    }

    _panelOffset = Offset(panelLeft - origin.dx, panelTop - origin.dy);
    _scrollController?.dispose();
    _scrollController = ScrollController(
      initialScrollOffset: initialScrollOffset,
    );
    _open = true;
    _portal.show();
    _reveal.forward(from: _reveal.value);
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _reveal.reverse();
    setState(() {});
  }

  void _select(CLSelectOption<T> option) {
    widget.onChanged?.call(option.value);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final selected = widget.options
        .where((o) => o.value == widget.value)
        .toList();
    final label = selected.isEmpty ? '' : selected.first.label;
    final textStyle =
        (widget.size == CLControlSize.large
                ? theme.typography.body
                : theme.typography.callout)
            .copyWith(
              color: _enabled ? colors.textPrimary : colors.textDisabled,
            );
    final radius =
        widget.borderRadius ?? BorderRadius.circular(theme.radii.control);

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: Semantics(
          button: true,
          enabled: _enabled,
          label: label,
          child: MouseRegion(
            cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: CLPressable(
              onTap: _enabled ? _toggle : null,
              borderRadius: radius,
              deformOnDrag: false,
              pressedScale: 1.02,
              child: SizedBox(
                width: widget.width,
                height: _height,
                child: CLSurface(
                  fill: _hovered && _enabled
                      ? colors.controlHighlight
                      : colors.control,
                  borderRadius: radius,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.size == CLControlSize.small ? 10 : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Chevrons(color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = CLTheme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: _open
                ? HitTestBehavior.opaque
                : HitTestBehavior.translucent,
            onPointerDown: (_) => _close(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topLeft,
          offset: _panelOffset,
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_reveal.value);
              return Opacity(
                opacity: _reveal.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment: _revealAlignment,
                  child: child,
                ),
              );
            },
            child: IgnorePointer(
              ignoring: !_open,
              child: SizedBox(
                width: _panelWidth,
                height: _panelHeight,
                child: CLSurface(
                  frosted: true,
                  borderRadius: BorderRadius.circular(theme.radii.medium),
                  outlined: true,
                  shadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                  child: CLList.builder(
                    controller: _scrollController,
                    itemCount: widget.options.length,
                    itemExtent: _rowHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _panelHorizontalPadding,
                      vertical: _panelPadding,
                    ),
                    blurExtent: const EdgeInsets.symmetric(vertical: 16),
                    borderRadius: BorderRadius.circular(theme.radii.medium),
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      return _OptionRow<T>(
                        option: option,
                        checked: option.value == widget.value,
                        height: _rowHeight,
                        onTap: () => _select(option),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionRow<T> extends StatefulWidget {
  final CLSelectOption<T> option;
  final bool checked;
  final double height;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.checked,
    required this.height,
    required this.onTap,
  });

  @override
  State<_OptionRow<T>> createState() => _OptionRowState<T>();
}

class _OptionRowState<T> extends State<_OptionRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: clSmoothDecoration(
            color: _hovered ? colors.control : const Color(0x00000000),
            borderRadius: BorderRadius.circular(theme.radii.control - 2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: widget.checked
                    ? Center(
                        child: CustomPaint(
                          size: const Size(12, 10),
                          painter: _CheckPainter(color: colors.textPrimary),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  widget.option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.callout.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Color color;

  const _CheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.05, size.height * 0.55)
        ..lineTo(size.width * 0.38, size.height * 0.9)
        ..lineTo(size.width * 0.95, size.height * 0.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => color != oldDelegate.color;
}

/// The stacked up/down chevrons of the mockup's dropdown fields.
class _Chevrons extends StatelessWidget {
  final Color color;

  const _Chevrons({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(9, 14),
      painter: _ChevronsPainter(color: color),
    );
  }
}

class _ChevronsPainter extends CustomPainter {
  final Color color;

  const _ChevronsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.15, h * 0.36)
        ..lineTo(w * 0.5, h * 0.08)
        ..lineTo(w * 0.85, h * 0.36),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.15, h * 0.64)
        ..lineTo(w * 0.5, h * 0.92)
        ..lineTo(w * 0.85, h * 0.64),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronsPainter oldDelegate) =>
      color != oldDelegate.color;
}
