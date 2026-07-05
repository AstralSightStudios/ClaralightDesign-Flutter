import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:claralight_ui/src/surfaces/glass.dart';
import 'package:claralight_ui/src/surfaces/interactive_glass.dart';

/// A single selectable entry inside a [CLLiquidMenu].
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

/// An iOS 26 style liquid glass popup menu.
///
/// Renders a round glass button ([child] is its content). Tapping it makes
/// the glass "grow" out of the button into the menu panel; selecting an
/// entry (or tapping outside) melts the panel back into the button.
///
/// While a pointer is down inside the panel, a soft light spreads out from
/// the touch point and follows it, highlighting the row underneath.
class CLLiquidMenu extends StatefulWidget {
  /// Content of the collapsed anchor button, typically an [Icon].
  final Widget child;

  /// Menu entries, grouped by separators.
  final List<CLMenuGroup> groups;

  /// Diameter of the collapsed anchor button.
  final double buttonSize;

  /// Width of the expanded menu panel.
  final double menuWidth;

  /// Corner radius of the expanded menu panel.
  final double cornerRadius;

  /// Tint of the glass panel. The alpha channel controls intensity.
  final Color glassColor;

  /// Backdrop blur strength of the expanded panel.
  final double blur;

  /// Called after the menu opened / closed.
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  const CLLiquidMenu({
    super.key,
    required this.child,
    required this.groups,
    this.buttonSize = 44,
    this.menuWidth = 260,
    this.cornerRadius = 26,
    this.glassColor = const Color(0xA85A5A60),
    this.blur = 26,
    this.onOpened,
    this.onClosed,
  });

  @override
  State<CLLiquidMenu> createState() => _CLLiquidMenuState();
}

class _CLLiquidMenuState extends State<CLLiquidMenu>
    with TickerProviderStateMixin {
  // Width springs open fast and bouncy; height is softer and lags half a
  // beat behind, which gives the panel its jelly stretch.
  static const _openSpringW = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 30,
  );
  static const _openSpringH = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 16,
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

  /// Anchor corner the panel grows from, e.g. topRight in the recording.
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
    _startSize = widget.buttonSize * 1.3;

    _open = true;
    _closing = false;
    _portal.show();
    // The initial velocity makes the blob burst out of the button before
    // the springs settle it, like liquid being released. Height starts a
    // beat after width, so the blob widens first, then stretches down and
    // bounces — the jelly wobble of the reference.
    _morphW.animateWith(
      SpringSimulation(_openSpringW, _morphW.value, 1, 3,
          tolerance: Tolerance.defaultTolerance),
    );
    Future.delayed(const Duration(milliseconds: 45), () {
      if (!mounted || !_open) return;
      _morphH.animateWith(
        SpringSimulation(_openSpringH, _morphH.value, 1, 2.4,
            tolerance: Tolerance.defaultTolerance),
      );
    });
    _content.animateTo(
      1,
      duration: const Duration(milliseconds: 360),
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
          animation: _morphW,
          builder: (context, child) {
            final hidden = (_morphW.value * 5).clamp(0.0, 1.0);
            return Opacity(opacity: 1 - hidden, child: child);
          },
          child: InteractiveGlass(
            onTap: _toggle,
            size: widget.buttonSize,
            blur: 3,
            child: widget.child,
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
            behavior: _open ? HitTestBehavior.opaque : HitTestBehavior.translucent,
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
    final tW = _morphW.value.clamp(0.0, 1.3);
    final tH = _morphH.value.clamp(0.0, 1.3);
    if (tW <= 0.001 && tH <= 0.001 && !_open) return const SizedBox.shrink();

    final w = ui.lerpDouble(_startSize, widget.menuWidth, tW)!;
    final h = ui.lerpDouble(_startSize, _menuHeight, tH)!;
    final radius = ui.lerpDouble(
      _startSize / 2,
      widget.cornerRadius,
      tH.clamp(0.0, 1.0),
    )!;

    final reveal = _content.value;
    final opacity = math.pow(reveal, 0.6).toDouble();
    final sigma = 16 * math.pow(1 - reveal, 1.3).toDouble();
    final shadowStrength = math.max(tW, tH).clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: !_open,
      child: SizedBox(
        width: w,
        height: h,
        child: Glass(
          blur: widget.blur,
          backgroundColor: widget.glassColor,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB((0x40 * shadowStrength).round(), 0, 0, 0),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // While morphing, the glass reads thicker and gathers
                // light — a milky wash that clears as the content sharpens.
                IgnorePointer(
                  child: ColoredBox(
                    color: Color.fromRGBO(
                      255,
                      255,
                      255,
                      0.30 * (1 - reveal) * math.sqrt(shadowStrength),
                    ),
                  ),
                ),
                OverflowBox(
                  alignment: _anchor,
                  minWidth: widget.menuWidth,
                  maxWidth: widget.menuWidth,
                  minHeight: _menuHeight,
                  maxHeight: _menuHeight,
                  child: Transform(
                    alignment: _anchor,
                    transform: Matrix4.identity()
                      ..scaleByDouble(
                          w / widget.menuWidth, h / _menuHeight, 1, 1),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: sigma < 0.1
                          ? _buildContent()
                          : ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                  sigmaX: sigma, sigmaY: sigma),
                              child: _buildContent(),
                            ),
                    ),
                  ),
                ),
              ],
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
    final scrolled = position.translate(0, _scroll.hasClients ? _scroll.offset : 0);
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
    if (visible && _strength.status != AnimationStatus.forward &&
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
      onHover: (event) => _updatePointer(event.localPosition, down: _pointerDown),
      onExit: (_) => _clearHover(),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _updatePointer(event.localPosition, down: true),
        onPointerMove: (event) => _updatePointer(event.localPosition, down: true),
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
    return const SizedBox(
      height: _MenuPanel.separatorHeight,
      child: Center(
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: Color(0x30FFFFFF)),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final CLMenuAction action;
  final bool showIconColumn;

  const _MenuRow({required this.action, required this.showIconColumn});

  static const _labelColor = Color(0xFFF2F2F2);
  static const _disabledColor = Color(0x5EEBEBF5);
  static const _subtitleColor = Color(0x99EBEBF5);

  @override
  Widget build(BuildContext context) {
    final color = action.enabled ? _labelColor : _disabledColor;

    return SizedBox(
      height: _MenuPanel.actionHeight(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: action.checked
                  ? Icon(Icons.check, size: 16, color: color)
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
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      letterSpacing: -0.4,
                      color: color,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (action.subtitle != null)
                    Text(
                      action.subtitle!,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        letterSpacing: -0.1,
                        color: _subtitleColor,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w400,
                      ),
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
      // the pointer is actually down, like the reference recording.
      final highlight = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.015 * strength + 0.05 * press)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(row.deflate(3), const Radius.circular(12)),
        highlight,
      );
    }

    // A dim, wide bloom rather than a spotlight: most of the energy sits in
    // the outer falloff so the light reads as diffusing through the glass.
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
