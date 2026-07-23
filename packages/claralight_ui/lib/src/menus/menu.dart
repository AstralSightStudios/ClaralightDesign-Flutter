import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../scrolling/cl_list.dart';
import '../surfaces/pressable.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// Controls one [CLMenu].
///
/// A controller may be attached to only one menu at a time.
class CLMenuController extends ChangeNotifier {
  bool _isOpen = false;
  ValueChanged<bool>? _attachedHandler;

  /// Whether the attached menu is logically open.
  bool get isOpen => _isOpen;

  /// Opens the attached menu.
  void open() => _setOpen(true);

  /// Closes the attached menu.
  void close() => _setOpen(false);

  /// Opens a closed menu and closes an open one.
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
      'A CLMenuController can only be attached to one CLMenu at a time.',
    );
    _attachedHandler = handler;
  }

  void _detach(ValueChanged<bool> handler) {
    if (identical(_attachedHandler, handler)) _attachedHandler = null;
  }
}

typedef CLMenuButtonBuilder =
    Widget Function(BuildContext context, VoidCallback onPressed);

/// The ClaraLight popup menu.
///
/// Tapping [anchor] morphs its round surface into a panel using the ClaraLight
/// jelly spring. The panel content is always hosted in a shrink-wrapped
/// [CLList]; callers own the rows, separators, and selection behavior in
/// [children]. A restrained local light follows an active press inside the
/// panel. Use a [CLMenuController] when a child should close the menu.
class CLMenu extends StatefulWidget {
  const CLMenu({
    super.key,
    required this.anchor,
    required this.children,
    this.controller,
    this.buttonBuilder,
    this.buttonSize = 44,
    this.menuWidth = 260,
    this.cornerRadius,
    this.padding = const EdgeInsets.all(10),
    this.onOpenChanged,
  }) : assert(buttonSize > 0 && buttonSize < double.infinity),
       assert(menuWidth > 0 && menuWidth < double.infinity),
       assert(
         cornerRadius == null ||
             (cornerRadius >= 0 && cornerRadius < double.infinity),
       );

  /// Content of the collapsed anchor button, typically an [Icon].
  final Widget anchor;

  /// Widgets displayed by the menu's internal [CLList].
  final List<Widget> children;

  /// Optional external controller. An internal controller is used when null.
  final CLMenuController? controller;

  /// Builds a custom trigger, such as a [CLButton]. When provided, the builder
  /// owns the trigger's semantics, focus, shape, and visual treatment.
  final CLMenuButtonBuilder? buttonBuilder;

  /// Diameter of the default collapsed anchor button.
  final double buttonSize;

  /// Width of the expanded menu panel.
  final double menuWidth;

  /// Corner radius of the expanded menu panel.
  ///
  /// Null uses the theme's panel radius.
  final double? cornerRadius;

  /// Insets that scroll with [children].
  final EdgeInsetsGeometry padding;

  /// Called when the logical open state changes.
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<CLMenu> createState() => _CLMenuState();
}

class _CLMenuState extends State<CLMenu> with TickerProviderStateMixin {
  static const _openTravelSpring = SpringDescription(
    mass: 1,
    stiffness: 510,
    damping: 27,
  );
  static const _openMorphDuration = Duration(milliseconds: 350);
  static const _closeTravelSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 29,
  );
  static const _closeMorphDuration = Duration(milliseconds: 200);
  final _link = LayerLink();
  final _anchorKey = GlobalKey();
  final _listKey = GlobalKey();
  final _portal = OverlayPortalController();
  final _focusScopeNode = FocusScopeNode(
    debugLabel: 'CLMenu',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  late final CLMenuController _internalController;
  late final AnimationController _travel;
  late final AnimationController _morph;
  late final AnimationController _content;
  late final AnimationController _resize;
  late final AnimationController _pressGlow;

  FocusNode? _previousFocus;
  Offset _pressPosition = Offset.zero;
  int? _pressPointer;
  bool _open = false;
  bool _closing = false;
  bool _disableAnimations = false;
  int _closeGeneration = 0;
  bool _measuring = false;
  Alignment _anchor = Alignment.topRight;
  bool _growDown = true;
  double _spaceBelow = 0;
  double _spaceAbove = 0;
  double _measurementLimit = 0;
  double _heightFrom = 0;
  double _heightTo = 0;
  double _collapsedWidth = 44;
  double _collapsedHeight = 44;

  CLMenuController get _controller => widget.controller ?? _internalController;

  double get _displayHeight => ui.lerpDouble(
    _heightFrom,
    _heightTo,
    Curves.easeOutQuart.transform(_resize.value),
  )!;

  double get _travelUnit => _travel.value.clamp(0.0, 1.0).toDouble();

  double get _morphProgress => _morph.value.clamp(0.0, 1.0).toDouble();

  double _springVelocity(AnimationController controller) =>
      controller.velocity.clamp(-3.0, 3.0).toDouble();

  Offset _travelCenter(Offset start, Offset end) =>
      Offset.lerp(start, end, _travel.value)!;

  Offset get _panelTravelDelta => Offset(
    -_anchor.x * (widget.menuWidth - _collapsedWidth) / 2,
    -_anchor.y * (_displayHeight - _collapsedHeight) / 2,
  );

  Offset get _triggerRecoilOffset => _travel.value < 0
      ? _travelCenter(Offset.zero, _panelTravelDelta)
      : Offset.zero;

  @override
  void initState() {
    super.initState();
    _internalController = CLMenuController();
    _travel = AnimationController.unbounded(vsync: this)
      ..addListener(_handleMotionTick);
    _morph = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_handleMotionTick);
    _content = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _resize = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..value = 1;
    _pressGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _controller._attach(_handleControllerState);
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerState(_controller.isOpen);
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
    } else if (_closing) {
      _closeGeneration++;
      _startNormalCloseAnimation();
    }
  }

  void _snapReducedMotionGeometry() {
    _travel.stop();
    _morph.stop();
    _resize.stop();
    if (_open) {
      _travel.value = 1;
      _morph.value = 1;
      _resize.value = 1;
      _animateReducedContent(1);
    } else if (_closing) {
      _startReducedCloseAnimation(_closeGeneration);
    }
  }

  TickerFuture _animateReducedContent(double target) => _content.animateTo(
    target,
    duration: CLMotion.reducedFade,
    curve: CLMotion.easeOut,
  );

  void _startReducedCloseAnimation(int closeGeneration) {
    _travel.stop();
    _morph.stop();
    _resize.stop();
    _travel.value = 1;
    _morph.value = 1;
    _resize.value = 1;
    _animateReducedContent(0).whenCompleteOrCancel(() {
      if (!mounted || !_closing || closeGeneration != _closeGeneration) return;
      _finishClose();
      _travel.value = 0;
      _morph.value = 0;
      _resize.value = 1;
    });
  }

  void _startNormalCloseAnimation() {
    _travel.animateWith(
      SpringSimulation(
        _closeTravelSpring,
        _travel.value,
        0,
        _springVelocity(_travel),
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    _animateMorphTo(
      0,
      baseDuration: _closeMorphDuration,
      curve: Curves.easeOutCubic,
    );
    _content.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(CLMenu oldWidget) {
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
    if (_open && widget.children.isEmpty) _controller.close();
  }

  @override
  void dispose() {
    _controller._detach(_handleControllerState);
    _restorePreviousFocus();
    _travel
      ..removeListener(_handleMotionTick)
      ..dispose();
    _morph
      ..removeListener(_handleMotionTick)
      ..dispose();
    _content.dispose();
    _resize.dispose();
    _pressGlow.dispose();
    _focusScopeNode.dispose();
    _internalController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_controller.isOpen && widget.children.isEmpty) return;
    _controller.toggle();
  }

  void _handleControllerState(bool value) {
    if (!mounted || value == _open) return;
    if (value) {
      if (widget.children.isEmpty) {
        _controller._setOpen(false);
        return;
      }
      _show();
    } else {
      _hide();
    }
  }

  void _show() {
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonBox =
        _anchorKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final buttonRect = origin & buttonBox.size;
    final overlaySize = overlayBox.size;
    _collapsedWidth = buttonRect.width;
    _collapsedHeight = buttonRect.height;

    final growLeft = buttonRect.center.dx > overlaySize.width / 2;
    _spaceBelow = math.max(
      overlaySize.height - buttonRect.top - 12,
      _collapsedHeight,
    );
    _spaceAbove = math.max(buttonRect.bottom - 12, _collapsedHeight);
    _measurementLimit = math.max(_spaceBelow, _spaceAbove);
    _anchor = Alignment(growLeft ? 1 : -1, -1);

    _previousFocus = FocusManager.instance.primaryFocus;
    _open = true;
    _closing = false;
    _closeGeneration++;
    _measuring = true;
    _portal.show();
    widget.onOpenChanged?.call(true);
    setState(() {});
  }

  void _handleMeasuredSize(Size size) {
    if (!mounted || !_open || size.height <= 0) return;

    if (_measuring) {
      _growDown = _spaceBelow >= size.height || _spaceBelow >= _spaceAbove;
      _anchor = Alignment(_anchor.x, _growDown ? -1 : 1);
      final available = _growDown ? _spaceBelow : _spaceAbove;
      final measuredHeight = math.max(
        _collapsedHeight,
        math.min(size.height, available),
      );
      _heightFrom = measuredHeight;
      _heightTo = measuredHeight;
      _resize.value = 1;
      _measuring = false;
      setState(() {});
      _startOpenAnimation();
      return;
    }

    final available = _growDown ? _spaceBelow : _spaceAbove;
    final nextHeight = math.max(
      _collapsedHeight,
      math.min(size.height, available),
    );
    if ((nextHeight - _heightTo).abs() <= 0.5) return;
    if (_disableAnimations) {
      _heightFrom = nextHeight;
      _heightTo = nextHeight;
      _resize.stop();
      _resize.value = 1;
    } else {
      _heightFrom = _displayHeight;
      _heightTo = nextHeight;
      _resize.forward(from: 0);
    }
  }

  void _startOpenAnimation() {
    if (_disableAnimations) {
      _travel.stop();
      _morph.stop();
      _resize.stop();
      _travel.value = 1;
      _morph.value = 1;
      _resize.value = 1;
      _animateReducedContent(1);
    } else {
      _travel
          .animateWith(
            SpringSimulation(
              _openTravelSpring,
              _travel.value,
              1,
              _springVelocity(_travel),
              tolerance: Tolerance.defaultTolerance,
            ),
          )
          .whenCompleteOrCancel(() => _settleOpenGeometry(_travel));
      _animateMorphTo(
        1,
        baseDuration: _openMorphDuration,
        curve: Curves.easeInOutCubic,
      );
      _content.animateTo(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestMenuFocus());
  }

  void _animateMorphTo(
    double target, {
    required Duration baseDuration,
    required Curve curve,
  }) {
    final distance = (target - _morph.value).abs().clamp(0.0, 1.0);
    if (distance <= 0.001) {
      _morph.value = target;
      return;
    }
    _morph.animateTo(
      target,
      duration: Duration(
        microseconds: math.max(
          1,
          (baseDuration.inMicroseconds * distance).round(),
        ),
      ),
      curve: curve,
    );
  }

  void _settleOpenGeometry(AnimationController controller) {
    if (!mounted || !_open || _disableAnimations || controller.isAnimating) {
      return;
    }
    controller.value = 1;
  }

  void _requestMenuFocus({bool retry = true}) {
    if (!mounted || !_open || _measuring) return;
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
          (_) => _requestMenuFocus(retry: false),
        );
      }
    }
  }

  void _hide() {
    _open = false;
    _closing = true;
    _measuring = false;
    final closeGeneration = ++_closeGeneration;
    _clearPanelPress();
    widget.onOpenChanged?.call(false);
    setState(() {});

    if (_disableAnimations) {
      _startReducedCloseAnimation(closeGeneration);
      return;
    }

    if (_travel.value <= 0.001 &&
        _morph.value <= 0.001 &&
        !_travel.isAnimating &&
        !_morph.isAnimating) {
      _finishClose();
      return;
    }
    _startNormalCloseAnimation();
  }

  void _handleMotionTick() {
    if (_closing &&
        _travel.value <= 0.001 &&
        _morph.value <= 0.001 &&
        !_travel.isAnimating &&
        !_morph.isAnimating) {
      _finishClose();
    }
  }

  void _finishClose() {
    if (!_closing) return;
    _closing = false;
    _travel.value = 0;
    _morph.value = 0;
    if (_portal.isShowing) _portal.hide();
    _restorePreviousFocus();
    if (mounted) setState(() {});
  }

  void _restorePreviousFocus() {
    final previousFocus = _previousFocus;
    _previousFocus = null;
    if (previousFocus?.canRequestFocus ?? false) previousFocus!.requestFocus();
  }

  void _handlePanelPointerDown(PointerDownEvent event) {
    if (!_open || _pressPointer != null) return;
    setState(() {
      _pressPointer = event.pointer;
      _pressPosition = event.localPosition;
    });
    _pressGlow.forward();
  }

  void _handlePanelPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pressPointer) return;
    setState(() => _pressPosition = event.localPosition);
  }

  void _handlePanelPointerEnd(PointerEvent event) {
    if (event.pointer != _pressPointer) return;
    _clearPanelPress();
  }

  void _clearPanelPress() {
    _pressPointer = null;
    _pressGlow.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _anchorKey,
          child: AnimatedBuilder(
            animation: Listenable.merge([_travel, _morph]),
            builder: (context, child) {
              final presence = (math.max(_travel.value, _morph.value) * 5)
                  .clamp(0.0, 1.0);
              return Transform.translate(
                offset: _triggerRecoilOffset,
                child: Opacity(opacity: 1 - presence, child: child),
              );
            },
            child: widget.buttonBuilder != null
                ? Semantics(
                    expanded: _open,
                    child: widget.buttonBuilder!(context, _toggle),
                  )
                : FocusableActionDetector(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.enter):
                          ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.space):
                          ActivateIntent(),
                    },
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (_) {
                          _toggle();
                          return null;
                        },
                      ),
                    },
                    child: Semantics(
                      button: true,
                      expanded: _open,
                      child: CLPressable(
                        onTap: _toggle,
                        borderRadius: BorderRadius.circular(
                          widget.buttonSize / 2,
                        ),
                        pressedScale: 1 + 4 / widget.buttonSize,
                        child: SizedBox(
                          width: widget.buttonSize,
                          height: widget.buttonSize,
                          child: CLSurface(
                            borderRadius: BorderRadius.circular(
                              widget.buttonSize / 2,
                            ),
                            child: Center(child: widget.anchor),
                          ),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: _open
                        ? HitTestBehavior.opaque
                        : HitTestBehavior.translucent,
                    onPointerDown: (_) => _controller.close(),
                  ),
                ),
                if (_measuring)
                  CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    targetAnchor: _anchor,
                    followerAnchor: _anchor,
                    child: Align(
                      alignment: _anchor,
                      child: ExcludeFocus(
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0,
                              child: _buildMeasuredList(
                                maxHeight: _measurementLimit,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _travel,
                      _morph,
                      _content,
                      _resize,
                      _pressGlow,
                    ]),
                    child: _buildMeasuredList(
                      maxHeight: _growDown ? _spaceBelow : _spaceAbove,
                    ),
                    builder: (context, child) => CompositedTransformFollower(
                      link: _link,
                      showWhenUnlinked: false,
                      targetAnchor: _anchor,
                      followerAnchor: _anchor,
                      offset: _panelTranslation,
                      child: Align(
                        alignment: _anchor,
                        child: _buildPanel(child!),
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

  Offset get _panelTranslation {
    final tMorph = _morphProgress;
    final targetHeight = _displayHeight;
    final width = ui.lerpDouble(_collapsedWidth, widget.menuWidth, tMorph)!;
    final height = ui.lerpDouble(_collapsedHeight, targetHeight, tMorph)!;
    final startCenter = Offset(
      -_anchor.x * _collapsedWidth / 2,
      -_anchor.y * _collapsedHeight / 2,
    );
    final endCenter = startCenter + _panelTravelDelta;
    final currentCenter = Offset(
      -_anchor.x * width / 2,
      -_anchor.y * height / 2,
    );
    return _travelCenter(startCenter, endCenter) - currentCenter;
  }

  Widget _buildPanel(Widget measuredList) {
    final theme = CLTheme.of(context);
    final tTravel = _travelUnit;
    final tMorph = _morphProgress;
    if (tTravel <= 0.001 && tMorph <= 0.001 && !_open) {
      return const SizedBox.shrink();
    }

    final targetHeight = _displayHeight;
    final width = ui.lerpDouble(_collapsedWidth, widget.menuWidth, tMorph)!;
    final height = ui.lerpDouble(_collapsedHeight, targetHeight, tMorph)!;
    final radius = ui.lerpDouble(
      math.min(_collapsedWidth, _collapsedHeight) / 2,
      widget.cornerRadius ?? theme.radii.panel,
      tMorph.clamp(0.0, 1.0),
    )!;
    final borderRadius = BorderRadius.circular(radius);
    final reveal = _content.value;
    final opacity = _disableAnimations ? 1.0 : math.pow(reveal, 0.6).toDouble();
    final shadowStrength = tMorph.clamp(0.0, 1.0);
    final presence =
        (_disableAnimations
                ? reveal.clamp(0.0, 1.0)
                : (math.max(tTravel, tMorph) * 5).clamp(0.0, 1.0))
            .toDouble();

    return IgnorePointer(
      ignoring: !_open,
      child: ExcludeFocus(
        excluding: !_open,
        child: ExcludeSemantics(
          excluding: !_open,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePanelPointerDown,
            onPointerMove: _handlePanelPointerMove,
            onPointerUp: _handlePanelPointerEnd,
            onPointerCancel: _handlePanelPointerEnd,
            child: Opacity(
              opacity: presence,
              child: SizedBox(
                width: width,
                height: height,
                child: CLSurface(
                  frosted: true,
                  borderRadius: borderRadius,
                  outlined: true,
                  outlineColor: theme.colors.outlineStrong,
                  shadow: [
                    BoxShadow(
                      color: Color.fromARGB(
                        (0x40 * shadowStrength).round(),
                        0,
                        0,
                        0,
                      ),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
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
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _CLMenuPressGlowPainter(
                            pointer: _pressPosition,
                            color: theme.colors.textPrimary,
                            strength: Curves.easeOutCubic.transform(
                              _pressGlow.value,
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: opacity.clamp(0.0, 1.0).toDouble(),
                        child: Flow(
                          delegate: _CLMenuContentFlowDelegate(
                            targetWidth: widget.menuWidth,
                            maxHeight: _growDown ? _spaceBelow : _spaceAbove,
                            alignment: _anchor,
                          ),
                          children: [measuredList],
                        ),
                      ),
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

  Widget _buildMeasuredList({required double maxHeight}) {
    return SizedBox(
      width: widget.menuWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _SizeReporter(
          onSizeChanged: _handleMeasuredSize,
          child: CLList(
            key: _listKey,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: widget.padding,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

class _CLMenuContentFlowDelegate extends FlowDelegate {
  const _CLMenuContentFlowDelegate({
    required this.targetWidth,
    required this.maxHeight,
    required this.alignment,
  });

  final double targetWidth;
  final double maxHeight;
  final Alignment alignment;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: targetWidth,
      maxWidth: targetWidth,
      minHeight: 0,
      maxHeight: maxHeight,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final childSize = context.getChildSize(0);
    if (childSize == null) return;

    final alignedOffset = Offset(
      (context.size.width - childSize.width) * (alignment.x + 1) / 2,
      (context.size.height - childSize.height) * (alignment.y + 1) / 2,
    );
    final transform = Matrix4.identity()
      ..translateByDouble(alignedOffset.dx, alignedOffset.dy, 0, 1);

    context.paintChild(0, transform: transform);
  }

  @override
  bool shouldRelayout(_CLMenuContentFlowDelegate oldDelegate) =>
      targetWidth != oldDelegate.targetWidth ||
      maxHeight != oldDelegate.maxHeight;

  @override
  bool shouldRepaint(_CLMenuContentFlowDelegate oldDelegate) =>
      alignment != oldDelegate.alignment;
}

class _CLMenuPressGlowPainter extends CustomPainter {
  const _CLMenuPressGlowPainter({
    required this.pointer,
    required this.color,
    required this.strength,
  });

  final Offset pointer;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0.001 || size.isEmpty) return;
    final radius = (size.width * 0.28).clamp(44.0, 72.0);
    final alpha = 0.07 * strength;
    final center = color.withValues(alpha: color.a * alpha);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          center,
          center.withValues(alpha: center.a * 0.35),
          center.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: pointer, radius: radius));
    canvas.drawCircle(pointer, radius, paint);
  }

  @override
  bool shouldRepaint(_CLMenuPressGlowPainter oldDelegate) =>
      pointer != oldDelegate.pointer ||
      color != oldDelegate.color ||
      strength != oldDelegate.strength;
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSizeChanged, required super.child});

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSizeChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSizeReporter renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_reportedSize == size) return;
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
  }
}
