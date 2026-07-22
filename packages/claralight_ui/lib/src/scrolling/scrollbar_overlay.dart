import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/motion.dart';
import 'types.dart';

/// Overlay scrollbars for one or two axes, driven by scroll controllers.
///
/// Internal component shared by [CLScrollable] and `CLList`. A null
/// controller for an axis means that axis has no scrollbar; pairing it with
/// [CLScrollbarVisibility.hidden] is the canonical way to disable it.
class CLScrollbarOverlay extends StatefulWidget {
  const CLScrollbarOverlay({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.horizontalVisibility,
    required this.verticalVisibility,
    required this.thumbColor,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final CLScrollbarVisibility horizontalVisibility;
  final CLScrollbarVisibility verticalVisibility;
  final Color thumbColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<CLScrollbarOverlay> createState() => _CLScrollbarOverlayState();
}

class _CLScrollbarOverlayState extends State<CLScrollbarOverlay>
    with SingleTickerProviderStateMixin {
  static const _fadeInDuration = CLMotion.standard;
  static const _fadeOutDelay = Duration(milliseconds: 300);
  static const _fadeOutDuration = Duration(milliseconds: 180);
  static const _fadeOutCurve = CLMotion.easeIn;

  late final AnimationController _opacity;
  Timer? _hideTimer;
  ScrollPosition? _horizontalPosition;
  ScrollPosition? _verticalPosition;
  bool _hovered = false;
  bool _disableAnimations = false;
  bool _positionSyncScheduled = false;
  bool _visibleTarget = false;

  bool get _hasAuto =>
      widget.horizontalVisibility == CLScrollbarVisibility.auto ||
      widget.verticalVisibility == CLScrollbarVisibility.auto;

  bool get _isScrolling =>
      (_horizontalPosition?.isScrollingNotifier.value ?? false) ||
      (_verticalPosition?.isScrollingNotifier.value ?? false);

  @override
  void initState() {
    super.initState();
    _opacity = AnimationController(vsync: this);
    _addControllerListeners();
    _schedulePositionSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _opacity.value = _visibleTarget ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant CLScrollbarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horizontalController != widget.horizontalController ||
        oldWidget.verticalController != widget.verticalController) {
      oldWidget.horizontalController?.removeListener(_handleControllerChanged);
      oldWidget.verticalController?.removeListener(_handleControllerChanged);
      _removePositionListeners();
      _addControllerListeners();
      _schedulePositionSync();
    }
    if (!_hasAuto) {
      _hideTimer?.cancel();
      _visibleTarget = false;
      _opacity.value = 0;
    }
  }

  void _addControllerListeners() {
    widget.horizontalController?.addListener(_handleControllerChanged);
    widget.verticalController?.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    final needsHorizontalSync =
        widget.horizontalController != null && _horizontalPosition == null;
    final needsVerticalSync =
        widget.verticalController != null && _verticalPosition == null;
    if (needsHorizontalSync || needsVerticalSync) {
      _schedulePositionSync();
    }
    _showAutoScrollbars();
    if (!_isScrolling) _scheduleHide();
  }

  void _schedulePositionSync() {
    if (_positionSyncScheduled) return;
    _positionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSyncScheduled = false;
      if (!mounted) return;
      _syncPositionListeners();
    });
  }

  void _syncPositionListeners() {
    final horizontal = widget.horizontalController?.hasClients == true
        ? widget.horizontalController!.position
        : null;
    final vertical = widget.verticalController?.hasClients == true
        ? widget.verticalController!.position
        : null;
    if (_horizontalPosition != horizontal) {
      _horizontalPosition?.isScrollingNotifier.removeListener(
        _handleScrollingChanged,
      );
      _horizontalPosition = horizontal;
      _horizontalPosition?.isScrollingNotifier.addListener(
        _handleScrollingChanged,
      );
    }
    if (_verticalPosition != vertical) {
      _verticalPosition?.isScrollingNotifier.removeListener(
        _handleScrollingChanged,
      );
      _verticalPosition = vertical;
      _verticalPosition?.isScrollingNotifier.addListener(
        _handleScrollingChanged,
      );
    }
    _handleScrollingChanged();
  }

  void _handleScrollingChanged() {
    if (_isScrolling) {
      _showAutoScrollbars();
    } else {
      _scheduleHide();
    }
  }

  void _showAutoScrollbars() {
    if (!_hasAuto) return;
    _hideTimer?.cancel();
    final wasVisibleTarget = _visibleTarget;
    _visibleTarget = true;
    if (_disableAnimations) {
      _opacity.value = 1;
    } else if (_opacity.value != 1 &&
        (!wasVisibleTarget || !_opacity.isAnimating)) {
      _opacity.animateTo(
        1,
        duration: _fadeInDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scheduleHide() {
    if (!_hasAuto || _hovered || _isScrolling) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(_fadeOutDelay, _hideAutoScrollbars);
  }

  void _hideAutoScrollbars() {
    if (!mounted || _hovered || _isScrolling) return;
    _visibleTarget = false;
    if (_disableAnimations) {
      _opacity.value = 0;
    } else {
      _opacity.animateTo(0, duration: _fadeOutDuration, curve: _fadeOutCurve);
    }
  }

  void _handleEnter(PointerEnterEvent event) {
    _hovered = true;
    _showAutoScrollbars();
  }

  void _handleExit(PointerExitEvent event) {
    _hovered = false;
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      child: widget.child,
      builder: (context, child) {
        Widget result = child!;
        if (widget.horizontalController != null &&
            widget.horizontalVisibility != CLScrollbarVisibility.hidden) {
          final opacity =
              widget.horizontalVisibility == CLScrollbarVisibility.always
              ? 1.0
              : _opacity.value;
          result = _buildRawScrollbar(
            axis: Axis.horizontal,
            controller: widget.horizontalController!,
            thumbColor: widget.thumbColor.withValues(
              alpha: widget.thumbColor.a * opacity,
            ),
            interactive: opacity > 0,
            padding: widget.padding,
            child: result,
          );
        }
        if (widget.verticalController != null &&
            widget.verticalVisibility != CLScrollbarVisibility.hidden) {
          final opacity =
              widget.verticalVisibility == CLScrollbarVisibility.always
              ? 1.0
              : _opacity.value;
          result = _buildRawScrollbar(
            axis: Axis.vertical,
            controller: widget.verticalController!,
            thumbColor: widget.thumbColor.withValues(
              alpha: widget.thumbColor.a * opacity,
            ),
            interactive: opacity > 0,
            padding: widget.padding,
            child: result,
          );
        }
        return MouseRegion(
          onEnter: _handleEnter,
          onExit: _handleExit,
          child: result,
        );
      },
    );
  }

  void _removePositionListeners() {
    _horizontalPosition?.isScrollingNotifier.removeListener(
      _handleScrollingChanged,
    );
    _verticalPosition?.isScrollingNotifier.removeListener(
      _handleScrollingChanged,
    );
    _horizontalPosition = null;
    _verticalPosition = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.horizontalController?.removeListener(_handleControllerChanged);
    widget.verticalController?.removeListener(_handleControllerChanged);
    _removePositionListeners();
    _opacity.dispose();
    super.dispose();
  }
}

Widget _buildRawScrollbar({
  required Axis axis,
  required ScrollController controller,
  required Color thumbColor,
  required bool interactive,
  required EdgeInsetsGeometry padding,
  required Widget child,
}) {
  return RawScrollbar(
    key: ValueKey(axis),
    controller: controller,
    thumbVisibility: true,
    interactive: interactive,
    thickness: 4,
    shape: clSmoothShape(const BorderRadius.all(Radius.circular(17))),
    thumbColor: thumbColor,
    minThumbLength: 49,
    trackVisibility: false,
    fadeDuration: Duration.zero,
    timeToFade: Duration.zero,
    mainAxisMargin: 2,
    scrollbarOrientation: axis == Axis.vertical
        ? ScrollbarOrientation.right
        : ScrollbarOrientation.bottom,
    padding: padding,
    notificationPredicate: (notification) =>
        notification.depth == 0 && notification.metrics.axis == axis,
    child: child,
  );
}
