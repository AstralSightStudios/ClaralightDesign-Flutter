import 'dart:async';

import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A ClaraLight tooltip.
///
/// Wrap any widget; hovering (desktop) or long-pressing (touch) reveals a
/// frosted label above it, popping in with a soft scale.
class CLTooltip extends StatefulWidget {
  /// Tooltip text ("这按钮是干嘛的").
  final String message;

  final Widget child;

  /// Hover dwell time before the tooltip appears.
  final Duration delay;

  /// Preferred side: above (default) or below the child.
  final bool preferBelow;

  const CLTooltip({
    super.key,
    required this.message,
    required this.child,
    this.delay = const Duration(milliseconds: 450),
    this.preferBelow = false,
  });

  @override
  State<CLTooltip> createState() => _CLTooltipState();
}

class _CLTooltipState extends State<CLTooltip>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  late final AnimationController _reveal;
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 120),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _portal.isShowing) {
          _portal.hide();
        }
      });
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  void _scheduleShow() {
    _dwell?.cancel();
    _dwell = Timer(widget.delay, _show);
  }

  void _show() {
    if (!mounted) return;
    if (!_portal.isShowing) _portal.show();
    _reveal.forward();
  }

  void _hide() {
    _dwell?.cancel();
    if (_reveal.value > 0) _reveal.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          onEnter: (_) => _scheduleShow(),
          onExit: (_) => _hide(),
          child: GestureDetector(
            onLongPress: _show,
            onLongPressEnd: (_) => _hide(),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = CLTheme.of(context);
    final below = widget.preferBelow;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor:
                  below ? Alignment.bottomCenter : Alignment.topCenter,
              followerAnchor:
                  below ? Alignment.topCenter : Alignment.bottomCenter,
              offset: Offset(0, below ? 6 : -6),
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) {
                  final t = Curves.easeOutBack.transform(_reveal.value);
                  return Opacity(
                    opacity: _reveal.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      alignment: below
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      child: child,
                    ),
                  );
                },
                child: CLSurface(
                  frosted: true,
                  borderRadius: BorderRadius.circular(theme.radii.control),
                  outlined: true,
                  shadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.message,
                    style: theme.typography.callout
                        .withCLWeight(FontWeight.w500)
                        .copyWith(color: theme.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
