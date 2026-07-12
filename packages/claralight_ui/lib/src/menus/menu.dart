import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
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

  /// Diameter of the collapsed anchor button.
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
  final _anchorKey = GlobalKey();
  final _listKey = GlobalKey();
  final _portal = OverlayPortalController();
  final _focusScopeNode = FocusScopeNode(
    debugLabel: 'CLMenu',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  late final CLMenuController _internalController;
  late final AnimationController _morphW;
  late final AnimationController _morphH;
  late final AnimationController _content;
  late final AnimationController _resize;
  late final AnimationController _pressGlow;

  FocusNode? _previousFocus;
  Offset _pressPosition = Offset.zero;
  int? _pressPointer;
  bool _open = false;
  bool _closing = false;
  bool _measuring = false;
  Alignment _anchor = Alignment.topRight;
  bool _growDown = true;
  double _spaceBelow = 0;
  double _spaceAbove = 0;
  double _measurementLimit = 0;
  double _heightFrom = 0;
  double _heightTo = 0;

  CLMenuController get _controller => widget.controller ?? _internalController;

  double get _displayHeight => ui.lerpDouble(
    _heightFrom,
    _heightTo,
    Curves.easeOutQuart.transform(_resize.value),
  )!;

  @override
  void initState() {
    super.initState();
    _internalController = CLMenuController();
    _morphW = AnimationController.unbounded(vsync: this)
      ..addListener(_handleMorphTick);
    _morphH = AnimationController.unbounded(vsync: this)
      ..addListener(_handleMorphTick);
    _content = AnimationController(vsync: this);
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
    _morphW
      ..removeListener(_handleMorphTick)
      ..dispose();
    _morphH
      ..removeListener(_handleMorphTick)
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

    final growLeft = buttonRect.center.dx > overlaySize.width / 2;
    _spaceBelow = math.max(
      overlaySize.height - buttonRect.top - 12,
      widget.buttonSize,
    );
    _spaceAbove = math.max(buttonRect.bottom - 12, widget.buttonSize);
    _measurementLimit = math.max(_spaceBelow, _spaceAbove);
    _anchor = Alignment(growLeft ? 1 : -1, -1);

    _previousFocus = FocusManager.instance.primaryFocus;
    _open = true;
    _closing = false;
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
        widget.buttonSize,
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
      widget.buttonSize,
      math.min(size.height, available),
    );
    if ((nextHeight - _heightTo).abs() <= 0.5) return;
    _heightFrom = _displayHeight;
    _heightTo = nextHeight;
    _resize.forward(from: 0);
  }

  void _startOpenAnimation() {
    _morphW.animateWith(
      SpringSimulation(
        _openSpringW,
        _morphW.value,
        1,
        2.2,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    Future.delayed(const Duration(milliseconds: 30), () {
      if (!mounted || !_open) return;
      _morphH.animateWith(
        SpringSimulation(
          _openSpringH,
          _morphH.value,
          1,
          1.6,
          tolerance: Tolerance.defaultTolerance,
        ),
      );
    });
    _content.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestMenuFocus());
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
    _clearPanelPress();
    widget.onOpenChanged?.call(false);
    setState(() {});

    if (_morphW.value <= 0.001 &&
        _morphH.value <= 0.001 &&
        !_morphW.isAnimating &&
        !_morphH.isAnimating) {
      _finishClose();
      return;
    }
    _morphW.animateWith(
      SpringSimulation(
        _closeSpringW,
        _morphW.value,
        0,
        0,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    _morphH.animateWith(
      SpringSimulation(
        _closeSpringH,
        _morphH.value,
        0,
        0,
        tolerance: Tolerance.defaultTolerance,
      ),
    );
    _content.animateTo(
      0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
    );
  }

  void _handleMorphTick() {
    if (_closing &&
        _morphW.value <= 0.001 &&
        _morphH.value <= 0.001 &&
        !_morphW.isAnimating &&
        !_morphH.isAnimating) {
      _finishClose();
    }
  }

  void _finishClose() {
    if (!_closing) return;
    _closing = false;
    if (_portal.isShowing) _portal.hide();
    final previousFocus = _previousFocus;
    _previousFocus = null;
    if (previousFocus?.canRequestFocus ?? false) previousFocus!.requestFocus();
    if (mounted) setState(() {});
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
            animation: Listenable.merge([_morphW, _morphH]),
            builder: (context, child) {
              final presence = (math.max(_morphW.value, _morphH.value) * 5)
                  .clamp(0.0, 1.0);
              return Opacity(opacity: 1 - presence, child: child);
            },
            child: FocusableActionDetector(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
                  borderRadius: BorderRadius.circular(widget.buttonSize / 2),
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
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: _anchor,
                  followerAnchor: _anchor,
                  child: Align(
                    alignment: _anchor,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _morphW,
                        _morphH,
                        _content,
                        _resize,
                        _pressGlow,
                      ]),
                      builder: (context, _) => _buildPanel(),
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

  Widget _buildPanel() {
    if (_measuring) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: _buildMeasuredList(maxHeight: _measurementLimit),
        ),
      );
    }

    final theme = CLTheme.of(context);
    final tW = _morphW.value.clamp(0.0, 1.3);
    final tH = _morphH.value.clamp(0.0, 1.3);
    if (tW <= 0.001 && tH <= 0.001 && !_open) {
      return const SizedBox.shrink();
    }

    final targetHeight = _displayHeight;
    final width = ui.lerpDouble(widget.buttonSize, widget.menuWidth, tW)!;
    final height = ui.lerpDouble(widget.buttonSize, targetHeight, tH)!;
    final radius = ui.lerpDouble(
      widget.buttonSize / 2,
      widget.cornerRadius ?? theme.radii.panel,
      tH.clamp(0.0, 1.0),
    )!;
    final borderRadius = BorderRadius.circular(radius);
    final reveal = _content.value;
    final opacity = math.pow(reveal, 0.6).toDouble();
    final shadowStrength = math.max(tW, tH).clamp(0.0, 1.0);
    final presence = (math.max(tW, tH) * 5).clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: !_open,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePanelPointerDown,
        onPointerMove: _handlePanelPointerMove,
        onPointerUp: _handlePanelPointerEnd,
        onPointerCancel: _handlePanelPointerEnd,
        child: Opacity(
          opacity: presence,
          child: Container(
            width: width,
            height: height,
            decoration: clSmoothDecoration(
              borderRadius: borderRadius,
              side: BorderSide(color: theme.colors.outlineStrong),
              shadows: [
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
            ),
            child: ClipRSuperellipse(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(child: ColoredBox(color: theme.colors.frost)),
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
                    OverflowBox(
                      alignment: _anchor,
                      minWidth: widget.menuWidth,
                      maxWidth: widget.menuWidth,
                      minHeight: 0,
                      maxHeight: _growDown ? _spaceBelow : _spaceAbove,
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * math.min(tW, tH).clamp(0.0, 1.0),
                        alignment: _anchor,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: _buildMeasuredList(
                            maxHeight: _growDown ? _spaceBelow : _spaceAbove,
                          ),
                        ),
                      ),
                    ),
                  ],
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
