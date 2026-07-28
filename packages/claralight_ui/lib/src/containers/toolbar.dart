import 'package:flutter/widgets.dart';

import '../buttons/button.dart';
import '../buttons/icon_button.dart';
import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';
import 'toolbar_scope.dart';

/// A Claralight toolbar capsule — the floating tool clusters at the top of
/// the desktop mockup.
///
/// Groups its children inside a single default-glass capsule, with optional
/// hairline dividers between them. Icon buttons inside use a transparent,
/// non-frosted resting treatment so the capsule remains the only background.
class CLToolbar extends StatefulWidget {
  final List<Widget> children;

  /// Whether hairline dividers separate the children.
  final bool dividers;

  /// Density inherited by buttons that do not specify their own size.
  final CLControlSize size;

  /// Effective height of the capsule.
  ///
  /// Defaults to [CLControlSize.controlHeight] for [size].
  double get height => _heightOverride ?? size.controlHeight;
  final double? _heightOverride;

  /// Horizontal padding inside the capsule.
  ///
  /// Optically compensated: the capsule's curved ends bow away from the
  /// content, so an end inset equal to the vertical gap (4 for a 36px
  /// control in the 44px capsule) still *reads* wider. One point tighter
  /// makes all four sides look even.
  final double padding;

  /// Gap between children when [dividers] is false.
  final double spacing;

  /// Overrides the default glass fill.
  final Color? fill;

  /// Whether the capsule draws its hairline outline.
  final bool outlined;

  const CLToolbar({
    super.key,
    required this.children,
    this.dividers = false,
    this.size = CLControlSize.large,
    double? height,
    this.padding = 3,
    this.spacing = 2,
    this.fill,
    this.outlined = true,
  }) : _heightOverride = height;

  @override
  State<CLToolbar> createState() => _CLToolbarState();
}

bool _isInteractiveTool(Widget child) => switch (child) {
  CLButton(:final onPressed) => onPressed != null,
  CLIconButton(:final onPressed) => onPressed != null,
  _ => true,
};

class _CLToolbarState extends State<CLToolbar> {
  final Set<int> _hoveredTools = <int>{};
  final Set<int> _pressedPointers = <int>{};

  bool get _hideDividers =>
      _hoveredTools.isNotEmpty || _pressedPointers.isNotEmpty;

  void _setToolHovered(int index, bool hovered) {
    final changed = hovered
        ? _hoveredTools.add(index)
        : _hoveredTools.remove(index);
    if (changed) setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pressedPointers.add(event.pointer)) setState(() {});
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_pressedPointers.remove(event.pointer)) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius = BorderRadius.circular(widget.height / 2);

    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) {
        if (widget.dividers) {
          items.add(
            AnimatedOpacity(
              opacity: _hideDividers ? 0 : 1,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: 1,
                height: widget.height * 0.5,
                child: ColoredBox(color: theme.colors.separator),
              ),
            ),
          );
        } else {
          items.add(SizedBox(width: widget.spacing));
        }
      }
      final child = widget.children[i];
      final interactive = _isInteractiveTool(child);
      items.add(
        MouseRegion(
          key: child.key == null ? null : ValueKey<Key>(child.key!),
          onEnter: interactive ? (_) => _setToolHovered(i, true) : null,
          onExit: interactive ? (_) => _setToolHovered(i, false) : null,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: interactive ? _handlePointerDown : null,
            onPointerUp: interactive ? _handlePointerEnd : null,
            onPointerCancel: interactive ? _handlePointerEnd : null,
            child: child,
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      // Overlay the outline so it does not shrink same-size descendants.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: clSmoothDecoration(
          borderRadius: radius,
          side: widget.outlined
              ? BorderSide(color: theme.colors.outline)
              : BorderSide.none,
        ),
        child: CLSurface(
          level: CLSurfaceLevel.control,
          fill: widget.fill ?? theme.colors.floatingControl,
          frosted: true,
          borderRadius: radius,
          padding: EdgeInsets.symmetric(horizontal: widget.padding),
          child: CLToolbarScope(
            size: widget.size,
            child: Row(mainAxisSize: MainAxisSize.min, children: items),
          ),
        ),
      ),
    );
  }
}
