import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'anchored_overlay.dart';

export 'anchored_overlay.dart' show CLPopoverPosition;

/// Builds a popover anchor or its content with the active controller.
typedef CLPopoverBuilder =
    Widget Function(BuildContext context, CLPopoverController controller);

/// Controls one [CLPopover].
///
/// A controller may be attached to only one popover at a time.
class CLPopoverController extends ChangeNotifier {
  bool _isOpen = false;
  ValueChanged<bool>? _attachedHandler;

  /// Whether the attached popover is logically open.
  bool get isOpen => _isOpen;

  /// Opens the attached popover.
  void open() => _setOpen(true);

  /// Closes the attached popover.
  void close() => _setOpen(false);

  /// Opens a closed popover and closes an open one.
  void toggle() => _setOpen(!_isOpen);

  void _setOpen(bool value) {
    if (_isOpen == value) return;
    _isOpen = value;
    notifyListeners();
    _attachedHandler?.call(value);
  }

  void _attach(ValueChanged<bool> handler) {
    assert(
      _attachedHandler == null || identical(_attachedHandler, handler),
      'A CLPopoverController can only be attached to one CLPopover at a time.',
    );
    _attachedHandler = handler;
  }

  void _detach(ValueChanged<bool> handler) {
    if (identical(_attachedHandler, handler)) _attachedHandler = null;
  }
}

/// A ClaraLight popover anchored to another widget.
///
/// The anchor owns its activation semantics. Connect [CLPopoverController.toggle]
/// to the button returned by [anchorBuilder]. The popover automatically avoids
/// system safe areas, the on-screen keyboard, and screen edges.
class CLPopover extends StatefulWidget {
  const CLPopover({
    super.key,
    required this.anchorBuilder,
    required this.popoverBuilder,
    this.controller,
    this.position = CLPopoverPosition.top,
    this.showArrow = true,
    this.padding = const EdgeInsets.all(12),
    this.onOpenChanged,
  });

  /// Builds the anchor. The supplied controller should handle activation.
  final CLPopoverBuilder anchorBuilder;

  /// Lazily builds the interactive popover content.
  final CLPopoverBuilder popoverBuilder;

  /// Optional external controller. An internal controller is used when null.
  final CLPopoverController? controller;

  /// Preferred physical side. The popover may flip to remain visible.
  final CLPopoverPosition position;

  /// Whether the popover surface includes its pointing arrow.
  final bool showArrow;

  /// Padding inside the popover surface.
  final EdgeInsetsGeometry padding;

  /// Called when the logical open state changes.
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<CLPopover> createState() => _CLPopoverState();
}

class _CLPopoverState extends State<CLPopover> with TickerProviderStateMixin {
  final _anchorKey = GlobalKey();
  final _tapRegionGroupId = Object();
  final _portal = OverlayPortalController();
  final _focusScopeNode = FocusScopeNode(
    debugLabel: 'CLPopover',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  late final CLPopoverController _internalController;
  late final AnimationController _reveal;
  late final AnimationController _spring;
  FocusNode? _previousFocus;
  bool _open = false;
  bool _disableAnimations = false;

  CLPopoverController get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = CLPopoverController();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 110),
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_handleAnimationStatus);
    _spring = AnimationController.unbounded(vsync: this);
    _controller._attach(_handleControllerState);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerState(true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _snapReducedMotionGeometry();
    } else if (_open) {
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 520, damping: 28),
          _spring.value,
          1,
          0,
        ),
      );
      _animateRevealForward();
    } else if (_portal.isShowing) {
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 600, damping: 38),
          _spring.value,
          0,
          0,
        ),
      );
      _animateRevealReverse();
    }
  }

  void _snapReducedMotionGeometry() {
    _spring.stop();
    _spring.value = (_portal.isShowing || _open || _reveal.value > 0) ? 1 : 0;
    if (_open) {
      _animateRevealForward();
    } else if (_portal.isShowing) {
      _animateRevealReverse();
    }
  }

  TickerFuture _animateRevealForward() => _disableAnimations
      ? _reveal.animateTo(1, duration: const Duration(milliseconds: 125))
      : _reveal.forward();

  TickerFuture _animateRevealReverse() => _disableAnimations
      ? _reveal.animateBack(0, duration: const Duration(milliseconds: 125))
      : _reveal.reverse();

  @override
  void didUpdateWidget(CLPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? _internalController;
    if (!identical(oldController, _controller)) {
      oldController._detach(_handleControllerState);
      _controller._attach(_handleControllerState);
      if (_controller.isOpen != _open) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleControllerState(_controller.isOpen);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller._detach(_handleControllerState);
    _reveal
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    _spring.dispose();
    _focusScopeNode.dispose();
    _internalController.dispose();
    super.dispose();
  }

  void _handleControllerState(bool value) {
    if (!mounted || value == _open) return;
    if (value) {
      _show();
    } else {
      _hide();
    }
  }

  void _show() {
    _previousFocus = FocusManager.instance.primaryFocus;
    _open = true;
    if (_disableAnimations) {
      _spring.stop();
      _spring.value = 1;
    }
    _portal.show();
    widget.onOpenChanged?.call(true);
    if (!_open || !_controller.isOpen) return;
    setState(() {});
    _animateRevealForward();
    if (!_disableAnimations) {
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 520, damping: 28),
          _spring.value,
          1,
          0,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPopoverFocus());
  }

  void _requestPopoverFocus({bool retry = true}) {
    if (!mounted || !_open) return;
    FocusNode? firstFocus;
    for (final node in _focusScopeNode.traversalDescendants) {
      if (node is! FocusScopeNode) {
        firstFocus = node;
        break;
      }
    }
    if (firstFocus != null) {
      firstFocus.requestFocus();
    } else {
      _focusScopeNode.requestFocus();
      if (retry) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _requestPopoverFocus(retry: false),
        );
      }
    }
  }

  void _hide() {
    _open = false;
    widget.onOpenChanged?.call(false);
    if (_open || _controller.isOpen) return;
    setState(() {});
    if (_reveal.isDismissed) {
      _handleAnimationStatus(AnimationStatus.dismissed);
      return;
    }
    if (_disableAnimations) {
      _spring.stop();
      _spring.value = 1;
      _animateRevealReverse();
      return;
    }
    _animateRevealReverse();
    _spring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 600, damping: 38),
        _spring.value,
        0,
        0,
      ),
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _open) return;
    if (_portal.isShowing) {
      _portal.hide();
      if (mounted) setState(() {});
    }
    if (_disableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_open && !_portal.isShowing) {
          _spring.stop();
          _spring.value = 0;
        }
      });
    }
    final previousFocus = _previousFocus;
    _previousFocus = null;
    if (previousFocus?.canRequestFocus ?? false) previousFocus!.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: TapRegion(
        groupId: _tapRegionGroupId,
        child: KeyedSubtree(
          key: _anchorKey,
          child: widget.anchorBuilder(context, _controller),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _controller.close();
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _controller.close,
        },
        child: FocusTraversalGroup(
          child: FocusScope(
            node: _focusScopeNode,
            child: TapRegion(
              groupId: _tapRegionGroupId,
              consumeOutsideTaps: false,
              onTapOutside: (_) => _controller.close(),
              child: AnimatedBuilder(
                animation: Listenable.merge([_reveal, _spring]),
                builder: (context, child) {
                  return CLAnchoredOverlay(
                    anchorKey: _anchorKey,
                    position: widget.position,
                    showArrow: widget.showArrow,
                    padding: widget.padding.resolve(Directionality.of(context)),
                    borderRadius: theme.radii.panel,
                    fill: colors.frost.withValues(alpha: colors.frost.a * 0.68),
                    outlineColor: colors.outlineStrong,
                    shadowColor: const Color(0x59000000),
                    shadowBlur: 24,
                    shadowOffset: const Offset(0, 10),
                    opacity:
                        (_disableAnimations
                                ? const Cubic(0.23, 1, 0.32, 1)
                                : Curves.easeOutCubic)
                            .transform(_reveal.value),
                    scale: 0.96 + 0.04 * _spring.value,
                    child: child!,
                  );
                },
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: widget.popoverBuilder(context, _controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
