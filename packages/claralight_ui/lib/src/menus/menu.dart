import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../surfaces/pressable.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A single selectable entry inside a [CLMenu].
class CLMenuAction {
  /// Main label of the entry.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional smaller line displayed below [label] (e.g. sort direction).
  final String? subtitle;

  /// Whether a leading checkmark is shown.
  final bool checked;

  /// Disabled entries are dimmed and cannot be selected.
  final bool enabled;

  /// Called when the entry is selected. The menu closes afterwards.
  final VoidCallback? onSelected;

  const CLMenuAction({
    required this.label,
    this.icon,
    this.subtitle,
    this.checked = false,
    this.enabled = true,
    this.onSelected,
  });
}

/// A group of [CLMenuAction]s, separated from other groups by a hairline.
class CLMenuGroup {
  final List<CLMenuAction> actions;

  const CLMenuGroup({required this.actions});
}

/// The ClaraLight popup menu.
///
/// Renders a round anchor button ([child] is its content). Tapping it makes
/// the panel "grow" out of the button with the ClaraLight jelly spring;
/// selecting an entry (or tapping outside) melts the panel back into the
/// button.
///
/// While a pointer is down inside the panel, a soft light spreads out from
/// the touch point and follows it, highlighting the row underneath.
class CLMenu extends StatefulWidget {
  /// Content of the collapsed anchor button, typically an [Icon].
  final Widget child;

  /// Menu entries, grouped by separators.
  final List<CLMenuGroup> groups;

  /// Diameter of the collapsed anchor button.
  final double buttonSize;

  /// Width of the expanded menu panel.
  final double menuWidth;

  /// Corner radius of the expanded menu panel. Null uses the theme's
  /// panel radius.
  final double? cornerRadius;

  /// Called after the menu opened / closed.
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  const CLMenu({
    super.key,
    required this.child,
    required this.groups,
    this.buttonSize = 44,
    this.menuWidth = 260,
    this.cornerRadius,
    this.onOpened,
    this.onClosed,
  });

  @override
  State<CLMenu> createState() => _CLMenuState();
}

class _CLMenuState extends State<CLMenu> with TickerProviderStateMixin {
  // Width springs open fast; height lags a beat behind and lands with a
  // single soft overshoot — an unfurl, not a wobble.
  static const _openSpringW = SpringDescription(
    mass: 1,
    stiffness: 700,
    damping: 34,
  );
  static const _openSpringH = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 26,
  );
  static const _closeSpringW = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 36,
  );
  static const _closeSpringH = SpringDescription(
    mass: 1,
    stiffness: 440,
    damping: 38,
  );

  final _link = LayerLink();
  final _portal = OverlayPortalController();

  /// 0 = collapsed into the button, 1 = fully expanded (may overshoot).
  late final AnimationController _morphW;
  late final AnimationController _morphH;

  /// 0 = content invisible/blurred, 1 = content crisp.
  late final AnimationController _content;

  bool _open = false;
  bool _closing = false;

  /// Anchor corner the panel grows from.
  Alignment _anchor = Alignment.topRight;
  double _menuHeight = 0;
  double _startSize = 44;

  @override
  void initState() {
    super.initState();
    _morphW = AnimationController.unbounded(vsync: this)
      ..addListener(_onMorphTick);
    _morphH = AnimationController.unbounded(vsync: this)
      ..addListener(_onMorphTick);
    _content = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _morphW.dispose();
    _morphH.dispose();
    _content.dispose();
    super.dispose();
  }

  void _onMorphTick() {
    if (_closing &&
        _morphW.value <= 0.001 &&
        _morphH.value <= 0.001 &&
        !_morphW.isAnimating &&
        !_morphH.isAnimating) {
      _closing = false;
      _portal.hide();
      widget.onClosed?.call();
      setState(() {});
    }
  }

  double get _contentHeight => _MenuPanel.measure(widget.groups);

  void _toggle() => _open ? _close() : _openMenu();

  void _openMenu() {
    if (widget.groups.isEmpty) return;

    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonBox = context.findRenderObject()! as RenderBox;
    final origin = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final buttonRect = origin & buttonBox.size;
    final overlaySize = overlayBox.size;

    final growLeft = buttonRect.center.dx > overlaySize.width / 2;
    final spaceBelow = overlaySize.height - buttonRect.top - 12;
    final spaceAbove = buttonRect.bottom - 12;
    final growDown =
        spaceBelow >= _contentHeight || spaceBelow >= spaceAbove;

    _anchor = Alignment(growLeft ? 1 : -1, growDown ? -1 : 1);
    _menuHeight = math.min(
      _contentHeight,
      math.max(growDown ? spaceBelow : spaceAbove, widget.buttonSize),
    );
    // The morph starts and ends exactly on the anchor button's circle so
    // the panel and the button always read as one object; the "burst" out
    // of the button comes from the springs' initial velocity alone.
    _startSize = widget.buttonSize;

    _open = true;
    _closing = false;
    _portal.show();
    // The initial velocity makes the panel burst out of the button before
    // the springs settle it. Height starts a beat after width, so the
    // panel widens first, then unfurls downward.
    _morphW.animateWith(
      SpringSimulation(_openSpringW, _morphW.value, 1, 2.2,
          tolerance: Tolerance.defaultTolerance),
    );
    Future.delayed(const Duration(milliseconds: 30), () {
      if (!mounted || !_open) return;
      _morphH.animateWith(
        SpringSimulation(_openSpringH, _morphH.value, 1, 1.6,
            tolerance: Tolerance.defaultTolerance),
      );
    });
    _content.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    widget.onOpened?.call();
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _closing = true;
    _morphW.animateWith(
      SpringSimulation(_closeSpringW, _morphW.value, 0, 0,
          tolerance: Tolerance.defaultTolerance),
    );
    _morphH.animateWith(
      SpringSimulation(_closeSpringH, _morphH.value, 0, 0,
          tolerance: Tolerance.defaultTolerance),
    );
    _content.animateTo(
      0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
    );
    setState(() {});
  }

  void _select(CLMenuAction action) {
    action.onSelected?.call();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: AnimatedBuilder(
          animation: Listenable.merge([_morphW, _morphH]),
          builder: (context, child) {
            // Crossfades with the panel (which uses the same curve
            // inverted), so open and close read as one surface morphing.
            final presence = (math.max(_morphW.value, _morphH.value) * 5)
                .clamp(0.0, 1.0);
            return Opacity(opacity: 1 - presence, child: child);
          },
          child: CLPressable(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(widget.buttonSize / 2),
            pressedScale: 1 + 4 / widget.buttonSize,
            child: SizedBox(
              width: widget.buttonSize,
              height: widget.buttonSize,
              child: CLSurface(
                borderRadius: BorderRadius.circular(widget.buttonSize / 2),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        // Tapping anywhere outside the panel dismisses the menu.
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
          targetAnchor: _anchor,
          followerAnchor: _anchor,
          child: Align(
            alignment: _anchor,
            child: AnimatedBuilder(
              animation: Listenable.merge([_morphW, _morphH, _content]),
              builder: (context, _) => _buildPanel(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final theme = CLTheme.of(context);
    final tW = _morphW.value.clamp(0.0, 1.3);
    final tH = _morphH.value.clamp(0.0, 1.3);
    if (tW <= 0.001 && tH <= 0.001 && !_open) return const SizedBox.shrink();

    final w = ui.lerpDouble(_startSize, widget.menuWidth, tW)!;
    final h = ui.lerpDouble(_startSize, _menuHeight, tH)!;
    final radius = ui.lerpDouble(
      _startSize / 2,
      widget.cornerRadius ?? theme.radii.panel,
      tH.clamp(0.0, 1.0),
    )!;
    final borderRadius = BorderRadius.circular(radius);

    final reveal = _content.value;
    final opacity = math.pow(reveal, 0.6).toDouble();
    final shadowStrength = math.max(tW, tH).clamp(0.0, 1.0);
    // Mirrors the anchor button's fade so the two crossfade in place
    // instead of popping between states.
    final presence = (math.max(tW, tH) * 5).clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: !_open,
      child: Opacity(
        opacity: presence,
        child: Container(
          width: w,
          height: h,
          decoration: clSmoothDecoration(
            borderRadius: borderRadius,
            side: BorderSide(color: theme.colors.outlineStrong),
            shadows: [
              BoxShadow(
                color:
                    Color.fromARGB((0x40 * shadowStrength).round(), 0, 0, 0),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: ColoredBox(color: theme.colors.frost),
                  ),
                  // A faint wash of light while morphing, gone by the time
                  // the content lands.
                  IgnorePointer(
                    child: ColoredBox(
                      color: Color.fromRGBO(
                        255,
                        255,
                        255,
                        0.06 * (1 - reveal) * math.sqrt(shadowStrength),
                      ),
                    ),
                  ),
                  // The content is laid out at its final size and pinned to
                  // the anchor corner; the growing panel reveals it while a
                  // slight *uniform* scale makes it emerge from the button.
                  // Never stretched — rows don't squash while unfurling.
                  OverflowBox(
                    alignment: _anchor,
                    minWidth: widget.menuWidth,
                    maxWidth: widget.menuWidth,
                    minHeight: _menuHeight,
                    maxHeight: _menuHeight,
                    child: Transform.scale(
                      scale: 0.8 +
                          0.2 * math.min(tW, tH).clamp(0.0, 1.0),
                      alignment: _anchor,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return _MenuPanel(
      groups: widget.groups,
      width: widget.menuWidth,
      height: _menuHeight,
      contentHeight: _contentHeight,
      onSelect: _select,
    );
  }
}

/// Expanded menu content: rows, separators, touch glow and row highlight.
class _MenuPanel extends StatefulWidget {
  final List<CLMenuGroup> groups;
  final double width;
  final double height;
  final double contentHeight;
  final ValueChanged<CLMenuAction> onSelect;

  const _MenuPanel({
    required this.groups,
    required this.width,
    required this.height,
    required this.contentHeight,
    required this.onSelect,
  });

  static const double rowHeight = 44;
  static const double subtitleRowHeight = 56;
  static const double verticalPadding = 10;
  static const double separatorHeight = 19;

  static double actionHeight(CLMenuAction action) =>
      action.subtitle != null ? subtitleRowHeight : rowHeight;

  static double measure(List<CLMenuGroup> groups) {
    var height = verticalPadding * 2;
    for (final group in groups) {
      for (final action in group.actions) {
        height += actionHeight(action);
      }
    }
    height += separatorHeight * math.max(0, groups.length - 1);
    return height;
  }

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _RowGeometry {
  final CLMenuAction action;
  final Rect rect;

  const _RowGeometry(this.action, this.rect);
}

class _MenuPanelState extends State<_MenuPanel>
    with TickerProviderStateMixin {
  /// Presence of the glow/highlight (hover or touch), 0..1.
  late final AnimationController _strength;

  /// Spread pulse while the pointer is down, 0..1.
  late final AnimationController _press;

  final _scroll = ScrollController();

  final List<_RowGeometry> _rows = [];
  Offset? _pointer;
  int _activeRow = -1;
  bool _pointerDown = false;

  @override
  void initState() {
    super.initState();
    _strength = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _computeRows();
  }

  @override
  void didUpdateWidget(_MenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups) _computeRows();
  }

  @override
  void dispose() {
    _strength.dispose();
    _press.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _computeRows() {
    _rows.clear();
    var y = _MenuPanel.verticalPadding;
    for (var g = 0; g < widget.groups.length; g++) {
      if (g > 0) y += _MenuPanel.separatorHeight;
      for (final action in widget.groups[g].actions) {
        final height = _MenuPanel.actionHeight(action);
        _rows.add(
          _RowGeometry(action, Rect.fromLTWH(0, y, widget.width, height)),
        );
        y += height;
      }
    }
  }

  int _rowAt(Offset position) {
    final scrolled =
        position.translate(0, _scroll.hasClients ? _scroll.offset : 0);
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].rect.contains(scrolled) && _rows[i].action.enabled) {
        return i;
      }
    }
    return -1;
  }

  void _updatePointer(Offset position, {required bool down}) {
    final row = _rowAt(position);
    setState(() {
      _pointer = position;
      _activeRow = row;
      _pointerDown = down;
    });
    final visible = row >= 0;
    if (visible &&
        _strength.status != AnimationStatus.forward &&
        _strength.value < 1) {
      _strength.forward();
    } else if (!visible && _strength.value > 0) {
      _strength.reverse();
    }
    if (down && visible && _press.status == AnimationStatus.dismissed) {
      _press.forward(from: 0);
    }
  }

  void _endPointer({bool select = false}) {
    if (select && _activeRow >= 0) {
      widget.onSelect(_rows[_activeRow].action);
    }
    setState(() => _pointerDown = false);
    _press.reverse();
    if (_activeRow < 0) _strength.reverse();
  }

  void _clearHover() {
    setState(() {
      _activeRow = -1;
      _pointerDown = false;
    });
    _strength.reverse();
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.contentHeight > widget.height + 0.5;

    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _buildRows(),
    );
    if (scrollable) {
      column = SingleChildScrollView(
        controller: _scroll,
        physics: const ClampingScrollPhysics(),
        child: column,
      );
    }

    return MouseRegion(
      onHover: (event) =>
          _updatePointer(event.localPosition, down: _pointerDown),
      onExit: (_) => _clearHover(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            _updatePointer(event.localPosition, down: true),
        onPointerMove: (event) =>
            _updatePointer(event.localPosition, down: true),
        onPointerUp: (_) => _endPointer(select: true),
        onPointerCancel: (_) => _endPointer(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_strength, _press]),
          builder: (context, child) {
            return CustomPaint(
              painter: _GlowPainter(
                pointer: _pointer,
                rowRect: _activeRow >= 0
                    ? _rows[_activeRow].rect.translate(
                        0, _scroll.hasClients ? -_scroll.offset : 0)
                    : null,
                strength: Curves.easeOut.transform(_strength.value),
                press: Curves.easeOutCubic.transform(_press.value),
                baseRadius: widget.width * 0.30,
              ),
              child: child,
            );
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: column,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRows() {
    final rows = <Widget>[];
    rows.add(const SizedBox(height: _MenuPanel.verticalPadding));
    for (var g = 0; g < widget.groups.length; g++) {
      if (g > 0) rows.add(const _GroupSeparator());
      final group = widget.groups[g];
      final hasIcons = group.actions.any((a) => a.icon != null);
      for (final action in group.actions) {
        rows.add(_MenuRow(action: action, showIconColumn: hasIcons));
      }
    }
    rows.add(const SizedBox(height: _MenuPanel.verticalPadding));
    return rows;
  }
}

class _GroupSeparator extends StatelessWidget {
  const _GroupSeparator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _MenuPanel.separatorHeight,
      child: Center(
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: CLTheme.of(context).colors.separator),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final CLMenuAction action;
  final bool showIconColumn;

  const _MenuRow({required this.action, required this.showIconColumn});

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final color = action.enabled ? colors.textSecondary : colors.textDisabled;

    return SizedBox(
      height: _MenuPanel.actionHeight(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: action.checked
                  ? Center(
                      child: CustomPaint(
                        size: const Size(13, 10),
                        painter: _CheckPainter(color: color),
                      ),
                    )
                  : null,
            ),
            if (showIconColumn)
              SizedBox(
                width: 32,
                child: action.icon != null
                    ? Icon(action.icon, size: 20, color: color)
                    : null,
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(color: color),
                  ),
                  if (action.subtitle != null)
                    Text(
                      action.subtitle!,
                      maxLines: 1,
                      style: theme.typography.caption
                          .copyWith(color: colors.textTertiary),
                    ),
                ],
              ),
            ),
          ],
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
        ..moveTo(0, size.height * 0.55)
        ..lineTo(size.width * 0.36, size.height)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Paints the hovered row highlight and the light that spreads out from the
/// touch point.
class _GlowPainter extends CustomPainter {
  final Offset? pointer;
  final Rect? rowRect;
  final double strength;
  final double press;
  final double baseRadius;

  const _GlowPainter({
    required this.pointer,
    required this.rowRect,
    required this.strength,
    required this.press,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0.01 || pointer == null) return;

    final row = rowRect;
    if (row != null) {
      // Hovering only casts the light bloom; the full-row wash appears once
      // the pointer is actually down.
      final highlight = Paint()
        ..color =
            Color.fromRGBO(255, 255, 255, 0.015 * strength + 0.05 * press)
        ..style = PaintingStyle.fill;
      canvas.drawRSuperellipse(
        RSuperellipse.fromRectAndRadius(
          row.deflate(3),
          const Radius.circular(12),
        ),
        highlight,
      );
    }

    // A dim, wide bloom rather than a spotlight: most of the energy sits in
    // the outer falloff so the light reads as diffusing through the surface.
    final radius = baseRadius * (0.55 + 0.75 * press);
    final alpha = 0.09 * strength + 0.12 * press;
    final center = Color.fromRGBO(255, 255, 255, alpha);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          center,
          center.withValues(alpha: alpha * 0.5),
          center.withValues(alpha: alpha * 0.15),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: pointer!, radius: radius))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(pointer!, radius, glow);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      pointer != oldDelegate.pointer ||
      rowRect != oldDelegate.rowRect ||
      strength != oldDelegate.strength ||
      press != oldDelegate.press;
}
