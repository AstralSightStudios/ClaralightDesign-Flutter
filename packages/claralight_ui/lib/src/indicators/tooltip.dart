import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../overlays/anchored_overlay.dart';
import '../theme/theme.dart';

export '../overlays/anchored_overlay.dart' show CLPopoverPosition;

/// A ClaraLight tooltip.
///
/// Wrap any widget; hovering (desktop) or long-pressing (touch) reveals a
/// frosted label near it, popping in from the pointing arrow.
class CLTooltip extends StatefulWidget {
  const CLTooltip({
    super.key,
    required this.message,
    required this.child,
    this.delay = const Duration(milliseconds: 450),
    this.position = CLPopoverPosition.top,
    this.showArrow = true,
    this.enableLongPress = true,
  });

  /// Tooltip text ("这按钮是干嘛的").
  final String message;

  final Widget child;

  /// Hover dwell time before the tooltip appears.
  final Duration delay;

  /// Preferred physical side. The tooltip may flip to remain visible.
  final CLPopoverPosition position;

  /// Whether the tooltip surface includes its pointing arrow.
  final bool showArrow;

  /// Whether touch and stylus long presses show the tooltip.
  final bool enableLongPress;

  @override
  State<CLTooltip> createState() => _CLTooltipState();
}

class _CLTooltipState extends State<CLTooltip> with TickerProviderStateMixin {
  final _anchorKey = GlobalKey();
  final _portal = OverlayPortalController();
  late final AnimationController _reveal;
  late final AnimationController _spring;
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _reveal =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 140),
          reverseDuration: const Duration(milliseconds: 110),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && _portal.isShowing) {
            _portal.hide();
          }
        });
    _spring = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _reveal.dispose();
    _spring.dispose();
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
    _spring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 560, damping: 27),
        _spring.value,
        1,
        0,
      ),
    );
  }

  void _hide() {
    _dwell?.cancel();
    if (_reveal.value > 0) {
      _reveal.reverse();
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 620, damping: 40),
          _spring.value,
          0,
          0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: KeyedSubtree(
        key: _anchorKey,
        child: MouseRegion(
          onEnter: (_) => _scheduleShow(),
          onExit: (_) => _hide(),
          child: GestureDetector(
            onLongPress: widget.enableLongPress ? _show : null,
            onLongPressEnd: widget.enableLongPress ? (_) => _hide() : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = CLTheme.of(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _spring]),
        builder: (context, child) {
          return CLAnchoredOverlay(
            anchorKey: _anchorKey,
            position: widget.position,
            showArrow: widget.showArrow,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            borderRadius: theme.radii.medium,
            fill: theme.colors.frost.withValues(
              alpha: theme.colors.frost.a * 0.68,
            ),
            outlineColor: theme.colors.outline,
            shadowColor: const Color(0x40000000),
            shadowBlur: 18,
            shadowOffset: const Offset(0, 6),
            opacity: Curves.easeOutCubic.transform(_reveal.value),
            scale: 0.92 + 0.08 * _spring.value,
            child: child!,
          );
        },
        child: Text(
          widget.message,
          style: theme.typography.callout
              .withCLWeight(FontWeight.w500)
              .copyWith(color: theme.colors.textSecondary),
        ),
      ),
    );
  }
}
