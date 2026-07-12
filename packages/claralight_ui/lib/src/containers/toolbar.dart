import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';
import 'toolbar_scope.dart';

/// A Claralight toolbar capsule — the floating tool clusters at the top of
/// the desktop mockup.
///
/// Groups its children inside a single control-fill capsule, with optional
/// hairline dividers between them. Icon buttons inside use a transparent,
/// non-frosted resting treatment so the capsule remains the only background.
class CLToolbar extends StatefulWidget {
  final List<Widget> children;

  /// Whether hairline dividers separate the children.
  final bool dividers;

  /// Height of the capsule.
  final double height;

  /// Horizontal padding inside the capsule.
  ///
  /// Optically compensated: the capsule's curved ends bow away from the
  /// content, so an end inset equal to the vertical gap (4 for a 36px
  /// control in the 44px capsule) still *reads* wider. One point tighter
  /// makes all four sides look even.
  final double padding;

  /// Gap between children.
  final double spacing;

  /// Overrides the control-level fill — the dark floating pills over the
  /// editor canvas use `Colors/Gray Alpha/11` instead.
  final Color? fill;

  /// Whether the capsule draws its hairline outline. Floating pills over
  /// imagery drop it and rely on their shadow.
  final bool outlined;

  const CLToolbar({
    super.key,
    required this.children,
    this.dividers = false,
    this.height = 44,
    this.padding = 3,
    this.spacing = 2,
    this.fill,
    this.outlined = true,
  });

  @override
  State<CLToolbar> createState() => _CLToolbarState();
}

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

    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) {
        if (widget.dividers) {
          items.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing + 2),
              child: AnimatedOpacity(
                opacity: _hideDividers ? 0 : 1,
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: 1,
                  height: widget.height * 0.5,
                  child: ColoredBox(color: theme.colors.separator),
                ),
              ),
            ),
          );
        } else {
          items.add(SizedBox(width: widget.spacing));
        }
      }
      items.add(
        MouseRegion(
          onEnter: (_) => _setToolHovered(i, true),
          onExit: (_) => _setToolHovered(i, false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerEnd,
            onPointerCancel: _handlePointerEnd,
            child: widget.children[i],
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: CLSurface(
        level: CLSurfaceLevel.control,
        fill: widget.fill,
        frosted: true,
        borderRadius: BorderRadius.circular(widget.height / 2),
        outlined: widget.outlined,
        shadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        padding: EdgeInsets.symmetric(horizontal: widget.padding),
        child: CLToolbarScope(
          child: Row(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}
