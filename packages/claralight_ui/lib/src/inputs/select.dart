import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
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

  const CLSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.size = CLControlSize.large,
    this.width,
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
  bool _dropUp = false;
  double _fieldWidth = 0;

  static const double _rowHeight = 36;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 140),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          _portal.hide();
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };

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
    final panelHeight = widget.options.length * _rowHeight + 12;
    _dropUp = origin.dy + fieldBox.size.height + 4 + panelHeight >
            overlayBox.size.height - 8 &&
        origin.dy - 4 - panelHeight > 8;
    _fieldWidth = fieldBox.size.width;

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
    final textStyle = (widget.size == CLControlSize.large
            ? theme.typography.body
            : theme.typography.callout)
        .copyWith(
      color: _enabled ? colors.textPrimary : colors.textDisabled,
    );
    final radius = BorderRadius.circular(theme.radii.control);

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
            behavior:
                _open ? HitTestBehavior.opaque : HitTestBehavior.translucent,
            onPointerDown: (_) => _close(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor:
              _dropUp ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor:
              _dropUp ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, _dropUp ? -4 : 4),
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, child) {
              final t = Curves.easeOutBack.transform(_reveal.value);
              return Opacity(
                opacity: _reveal.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment: _dropUp
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  child: child,
                ),
              );
            },
            child: IgnorePointer(
              ignoring: !_open,
              child: SizedBox(
                width: _fieldWidth,
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final option in widget.options)
                        _OptionRow<T>(
                          option: option,
                          checked: option.value == widget.value,
                          height: _rowHeight,
                          onTap: () => _select(option),
                        ),
                    ],
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
          margin: const EdgeInsets.symmetric(horizontal: 6),
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
                  style: theme.typography.callout
                      .copyWith(color: colors.textPrimary),
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
