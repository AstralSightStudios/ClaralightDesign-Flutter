import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../indicators/divider.dart';
import '../lists/list_tile.dart';
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

/// A row that opens a nested page inside the nearest [CLMenu].
///
/// Nested pages inherit the owning menu's width, padding, surface, and motion.
/// The row becomes a fixed header while its page is open; activating that
/// header returns to the previous page. Empty submenus remain inert.
class CLMenuSubmenu extends StatefulWidget {
  const CLMenuSubmenu({
    super.key,
    required this.label,
    required this.children,
    this.leading,
    this.tint,
    this.size = CLControlSize.medium,
    this.labelMaxLines = 1,
  }) : assert(labelMaxLines == null || labelMaxLines > 0);

  /// Accessible label and default text shown by the trigger/header row.
  final String label;

  /// Rows shown below the fixed header and divider.
  final List<Widget> children;

  /// Optional leading icon shared by the trigger and fixed header.
  final Widget? leading;

  /// Optional tint shared by the trigger and fixed header.
  final Color? tint;

  /// Control size shared by the trigger and fixed header.
  final CLControlSize size;

  /// Maximum lines used by the label.
  final int? labelMaxLines;

  @override
  State<CLMenuSubmenu> createState() => _CLMenuSubmenuState();
}

class _CLMenuSubmenuState extends State<CLMenuSubmenu> {
  final Object _identity = Object();
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _focusNode = FocusNode(debugLabel: 'CLMenuSubmenu');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _open(_CLMenuScope scope) {
    if (widget.children.isEmpty) return;
    scope.openSubmenu(
      identity: _identity,
      triggerKey: _triggerKey,
      returnFocusNode: _focusNode,
      definition: _CLMenuSubmenuDefinition.fromWidget(widget),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = _CLMenuScope.maybeOf(context);
    assert(
      scope != null,
      'CLMenuSubmenu must be placed inside CLMenu.children or another '
      'CLMenuSubmenu.children list.',
    );

    if (scope == null) {
      return _CLMenuSubmenuRow(
        definition: _CLMenuSubmenuDefinition.fromWidget(widget),
        focusNode: _focusNode,
        progress: 0,
      );
    }

    final definition = _CLMenuSubmenuDefinition.fromWidget(widget);
    scope.updateSubmenuDefinition(_identity, definition);
    final placeholderSize = scope.placeholderSizeFor(_identity);
    if (placeholderSize != null) {
      return SizedBox(height: placeholderSize.height, width: double.infinity);
    }

    return KeyedSubtree(
      key: _triggerKey,
      child: _CLMenuSubmenuRow(
        definition: definition,
        focusNode: _focusNode,
        progress: 0,
        onPressed: widget.children.isEmpty ? null : () => _open(scope),
      ),
    );
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

  /// Preferred width of the expanded menu panel.
  ///
  /// On open, the panel is clamped to the safe space available in its chosen
  /// horizontal expansion direction.
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
    stiffness: 700,
    damping: 30,
  );
  static const _openMorphDuration = Duration(milliseconds: 380);
  static const _closeTravelSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 28,
  );
  static const _closeMorphDuration = Duration(milliseconds: 160);
  static const _submenuOpenDuration = Duration(milliseconds: 260);
  static const _submenuCloseDuration = Duration(milliseconds: 180);
  static const _screenMargin = 12.0;
  static const _retreatScale = 0.96;
  static const _retreatOpacity = 0.72;
  final _link = LayerLink();
  final _anchorKey = GlobalKey();
  final _listKey = GlobalKey();
  final _overlayKey = GlobalKey();
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
  late final AnimationController _stackClose;

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
  double _expandedWidth = 44;
  Rect _rootButtonRect = Rect.zero;
  Offset _rootOpeningAnchor = Offset.zero;
  int _submenuRevision = 0;
  int _submenuGeneration = 0;
  final List<_CLMenuPageEntry> _submenuPages = [];

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
    -_anchor.x * (_expandedWidth - _collapsedWidth) / 2,
    -_anchor.y * (_displayHeight - _collapsedHeight) / 2,
  );

  Offset get _triggerRecoilOffset => _travel.value < 0
      ? _travelCenter(Offset.zero, _panelTravelDelta)
      : Offset.zero;

  @override
  void initState() {
    super.initState();
    _expandedWidth = widget.menuWidth;
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
    _stackClose = AnimationController(
      vsync: this,
      duration: _closeMorphDuration,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_handleSubmenuMotionTick);
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
    for (final page in _submenuPages) {
      page.progress.stop();
      if (page.started) page.progress.value = 1;
    }
    if (_open) {
      _stackClose.stop();
      _stackClose.value = 0;
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
    if (_submenuPages.isNotEmpty) {
      _stackClose.animateTo(
        1,
        duration: CLMotion.reducedFade,
        curve: CLMotion.easeOut,
      );
    }
    _animateReducedContent(0).whenCompleteOrCancel(() {
      if (!mounted || !_closing || closeGeneration != _closeGeneration) return;
      _finishClose();
      _travel.value = 0;
      _morph.value = 0;
      _resize.value = 1;
    });
  }

  void _startNormalCloseAnimation() {
    if (_submenuPages.isNotEmpty) {
      _stackClose.animateTo(
        1,
        duration: _closeMorphDuration,
        curve: Curves.easeOutCubic,
      );
    }
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
    _content.animateTo(
      0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(CLMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_open && !_closing && oldWidget.menuWidth != widget.menuWidth) {
      _expandedWidth = widget.menuWidth;
    }
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
    _stackClose
      ..removeListener(_handleSubmenuMotionTick)
      ..dispose();
    for (final page in _submenuPages) {
      page.dispose();
    }
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
    if (_submenuPages.isNotEmpty) _clearSubmenus();
    _stackClose.stop();
    _stackClose.value = 0;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonBox =
        _anchorKey.currentContext!.findRenderObject()! as RenderBox;
    final buttonRect = MatrixUtils.transformRect(
      buttonBox.getTransformTo(overlayBox),
      Offset.zero & buttonBox.size,
    );
    final safeRect = _safeRectFor(overlayBox.size);
    _rootButtonRect = buttonRect;
    _collapsedWidth = buttonRect.width;
    _collapsedHeight = buttonRect.height;

    final growLeft = buttonRect.center.dx > safeRect.center.dx;
    final availableWidth = growLeft
        ? buttonRect.right - safeRect.left
        : safeRect.right - buttonRect.left;
    _expandedWidth = math.min(
      widget.menuWidth,
      math.max(_collapsedWidth, availableWidth),
    );
    _spaceBelow = math.max(safeRect.bottom - buttonRect.top, _collapsedHeight);
    _spaceAbove = math.max(buttonRect.bottom - safeRect.top, _collapsedHeight);
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
      _rootOpeningAnchor = Offset(
        _anchor.x > 0 ? _rootButtonRect.right : _rootButtonRect.left,
        _anchor.y > 0 ? _rootButtonRect.bottom : _rootButtonRect.top,
      );
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
        duration: const Duration(milliseconds: 220),
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

  Rect _safeRectFor(Size overlaySize) {
    final media = MediaQuery.of(context);
    final left =
        math.max(media.viewPadding.left, media.viewInsets.left) + _screenMargin;
    final top =
        math.max(media.viewPadding.top, media.viewInsets.top) + _screenMargin;
    final right =
        overlaySize.width -
        math.max(media.viewPadding.right, media.viewInsets.right) -
        _screenMargin;
    final bottom =
        overlaySize.height -
        math.max(media.viewPadding.bottom, media.viewInsets.bottom) -
        _screenMargin;
    final safeLeft = left.clamp(0.0, overlaySize.width).toDouble();
    final safeTop = top.clamp(0.0, overlaySize.height).toDouble();
    return Rect.fromLTRB(
      safeLeft,
      safeTop,
      right.clamp(safeLeft, overlaySize.width).toDouble(),
      bottom.clamp(safeTop, overlaySize.height).toDouble(),
    );
  }

  void _openSubmenu({
    required Object identity,
    required GlobalKey triggerKey,
    required FocusNode returnFocusNode,
    required _CLMenuSubmenuDefinition definition,
  }) {
    if (!_open || _closing || definition.children.isEmpty) return;
    if (_submenuPages.any((page) => identical(page.sourceIdentity, identity))) {
      return;
    }

    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final triggerBox = triggerKey.currentContext?.findRenderObject();
    if (triggerBox is! RenderBox || !triggerBox.hasSize) return;
    final sourceRect = MatrixUtils.transformRect(
      triggerBox.getTransformTo(overlayBox),
      Offset.zero & triggerBox.size,
    );
    final safeRect = _safeRectFor(overlayBox.size);
    if (safeRect.isEmpty) return;
    final resolvedPadding = widget.padding.resolve(Directionality.of(context));
    final preferredWidth = math.max(
      _expandedWidth,
      sourceRect.width + resolvedPadding.horizontal,
    );
    final targetWidth = math.min(preferredWidth, safeRect.width);
    final progress = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_handleSubmenuMotionTick);
    final page = _CLMenuPageEntry(
      generation: ++_submenuGeneration,
      sourceIdentity: identity,
      definition: definition,
      sourceRect: sourceRect,
      placeholderSize: triggerBox.size,
      safeRect: safeRect,
      padding: resolvedPadding,
      targetWidth: targetWidth,
      returnFocusNode: returnFocusNode,
      progress: progress,
      onProgressTick: _handleSubmenuMotionTick,
    );
    _submenuPages.add(page);
    _submenuRevision++;
    setState(() {});
  }

  void _handleSubmenuSize(_CLMenuPageEntry page, Size size) {
    if (!mounted || !_open || !_submenuPages.contains(page) || size.isEmpty) {
      return;
    }
    final targetHeight = math.min(
      math.max(size.height, page.sourceRect.height),
      page.safeRect.height,
    );
    const surfaceInset = 1.0;
    final desiredLeft = page.sourceRect.left - page.padding.left - surfaceInset;
    final desiredTop = page.sourceRect.top - page.padding.top - surfaceInset;
    final maxLeft = page.safeRect.right - page.targetWidth;
    final maxTop = page.safeRect.bottom - targetHeight;
    page.targetRect = Rect.fromLTWH(
      desiredLeft.clamp(page.safeRect.left, maxLeft).toDouble(),
      desiredTop.clamp(page.safeRect.top, maxTop).toDouble(),
      page.targetWidth,
      targetHeight,
    );

    if (page.started) {
      setState(() {});
      return;
    }

    page.started = true;
    _submenuRevision++;
    setState(() {});
    if (_disableAnimations) {
      page.progress.animateTo(
        1,
        duration: CLMotion.reducedFade,
        curve: CLMotion.easeOut,
      );
    } else {
      page.progress.animateTo(
        1,
        duration: _submenuOpenDuration,
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open && _submenuPages.contains(page)) {
        page.headerFocusNode.requestFocus();
      }
    });
  }

  void _popSubmenu(_CLMenuPageEntry page) {
    if (!_open || _closing || _submenuPages.isEmpty) return;
    if (!identical(_submenuPages.last, page)) return;
    // The trigger and header occupy the same screen rect. Ignore a second tap
    // until the push settles so a quick double-tap cannot open and immediately
    // close the submenu, which otherwise looks like a missed interaction.
    if (page.progress.isAnimating && page.progress.value < 0.999) return;
    final generation = ++page.generation;
    final duration = _disableAnimations
        ? CLMotion.reducedFade
        : _submenuCloseDuration;
    page.progress
        .animateBack(0, duration: duration, curve: Curves.easeOutCubic)
        .whenCompleteOrCancel(() {
          if (!mounted || !_open || _closing) return;
          if (_submenuPages.isEmpty || !identical(_submenuPages.last, page)) {
            return;
          }
          if (page.generation != generation || page.progress.value > 0.001) {
            return;
          }
          _submenuPages.removeLast();
          _submenuRevision++;
          page.dispose();
          setState(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _open && page.returnFocusNode.canRequestFocus) {
              page.returnFocusNode.requestFocus();
            }
          });
        });
  }

  void _handleSubmenuMotionTick() {
    if (mounted) setState(() {});
  }

  void _updateSubmenuDefinition(
    Object identity,
    _CLMenuSubmenuDefinition definition,
  ) {
    for (final page in _submenuPages) {
      if (identical(page.sourceIdentity, identity)) {
        if (page.definition.matches(definition)) return;
        page.definition = definition;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _submenuPages.contains(page)) setState(() {});
        });
        return;
      }
    }
  }

  void _clearSubmenus() {
    if (_submenuPages.isEmpty) return;
    _submenuGeneration++;
    final pages = List<_CLMenuPageEntry>.of(_submenuPages);
    _submenuPages.clear();
    _submenuRevision++;
    for (final page in pages) {
      page.dispose();
    }
  }

  double _submenuDepthForPage(int pageIndex) {
    var depth = 0.0;
    for (var i = pageIndex; i < _submenuPages.length; i++) {
      final page = _submenuPages[i];
      if (page.started) depth += page.progress.value;
    }
    return depth;
  }

  double _submenuContentOpacityForPage(int pageIndex) {
    final depth = _submenuDepthForPage(pageIndex);
    if (depth <= 0.001) return 1;
    return math.pow(_retreatOpacity, depth).toDouble();
  }

  void _hide() {
    _open = false;
    _closing = true;
    _measuring = false;
    final closeGeneration = ++_closeGeneration;
    for (final page in _submenuPages) {
      page.generation++;
    }
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
    _clearSubmenus();
    _stackClose.stop();
    _stackClose.value = 0;
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
    final rootIsActive = !_submenuPages.any((page) => page.started);
    return _CLMenuScope(
      state: this,
      revision: _submenuRevision,
      child: PopScope(
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
                key: _overlayKey,
                clipBehavior: Clip.none,
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
                          child: _buildPageInteraction(
                            active: rootIsActive && _open,
                            child: _buildRetreatedPage(
                              pageIndex: 0,
                              alignment: _anchor,
                              child: _buildPanel(child!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (var i = 0; i < _submenuPages.length; i++)
                    _buildSubmenuPage(_submenuPages[i], i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageInteraction({required bool active, required Widget child}) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: ExcludeSemantics(excluding: !active, child: child),
      ),
    );
  }

  Widget _buildRetreatedPage({
    required int pageIndex,
    required Alignment alignment,
    Offset? origin,
    required Widget child,
  }) {
    final rawDepth = _submenuDepthForPage(pageIndex);
    final depth = _closing ? rawDepth * (1 - _stackClose.value) : rawDepth;
    if (depth <= 0.001) return child;
    final scale = _disableAnimations
        ? 1.0
        : math.pow(_retreatScale, depth).toDouble();
    final transform = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
    return RepaintBoundary(
      child: Transform(
        alignment: origin == null ? alignment : null,
        origin: origin,
        transform: transform,
        child: child,
      ),
    );
  }

  Widget _buildSubmenuPage(_CLMenuPageEntry page, int routeIndex) {
    if (!page.started || page.targetRect == null) {
      return Positioned(
        left: page.safeRect.left,
        top: page.safeRect.top,
        width: page.targetWidth,
        child: IgnorePointer(
          child: ExcludeFocus(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: page.safeRect.height),
                  child: _buildSubmenuContent(page, measuring: true),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final progress = page.progress.value.clamp(0.0, 1.0).toDouble();
    final targetRect = page.targetRect!;
    final currentRect = _disableAnimations
        ? targetRect
        : Rect.lerp(page.sourceRect, targetRect, progress)!;
    final isTop =
        _submenuPages.isNotEmpty && identical(_submenuPages.last, page);
    final localGroupOrigin = _rootOpeningAnchor - currentRect.topLeft;

    return Positioned.fromRect(
      rect: currentRect,
      child: _buildPageInteraction(
        active: isTop && _open && page.started,
        child: _buildClosingStackPage(
          currentRect: currentRect,
          child: _buildRetreatedPage(
            pageIndex: routeIndex + 1,
            alignment: Alignment.topLeft,
            origin: localGroupOrigin,
            child: _buildSubmenuSurface(
              page,
              progress,
              pageIndex: routeIndex + 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosingStackPage({
    required Rect currentRect,
    required Widget child,
  }) {
    final progress = _stackClose.value.clamp(0.0, 1.0).toDouble();
    if (!_closing || progress <= 0.001) return child;
    final targetScale = math.max(0.18, _collapsedWidth / _expandedWidth);
    final scale = _disableAnimations
        ? 1.0
        : ui.lerpDouble(1, targetScale, progress)!;
    final origin = _rootOpeningAnchor - currentRect.topLeft;
    return Transform(
      origin: origin,
      transform: Matrix4.identity()..scaleByDouble(scale, scale, 1, 1),
      child: child,
    );
  }

  Widget _buildSubmenuSurface(
    _CLMenuPageEntry page,
    double progress, {
    required int pageIndex,
  }) {
    final theme = CLTheme.of(context);
    final radius = ui.lerpDouble(
      theme.radii.control,
      widget.cornerRadius ?? theme.radii.panel,
      _disableAnimations ? 1 : progress,
    )!;
    final closingProgress = _closing
        ? _stackClose.value.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final materialPresence =
        1 -
        const Interval(
          0.12,
          0.55,
          curve: Curves.easeInCubic,
        ).transform(closingProgress);
    final shadowStrength = progress * materialPresence;
    final closingContentOpacity = _closing
        ? 1 -
              const Interval(
                0,
                0.24,
                curve: Curves.easeOut,
              ).transform(_stackClose.value.clamp(0.0, 1.0).toDouble())
        : 1.0;
    return CLSurface(
      frosted: true,
      frostSigma: 36 * materialPresence,
      fill: theme.colors.frost.withValues(
        alpha: theme.colors.frost.a * materialPresence,
      ),
      borderRadius: BorderRadius.circular(radius),
      outlined: true,
      outlineColor: theme.colors.outlineStrong.withValues(
        alpha: theme.colors.outlineStrong.a * materialPresence,
      ),
      shadow: [
        BoxShadow(
          color: Color.fromARGB((0x40 * shadowStrength).round(), 0, 0, 0),
          blurRadius: 36,
          offset: const Offset(0, 14),
        ),
      ],
      child: Opacity(
        opacity:
            _submenuContentOpacityForPage(pageIndex) *
            (_disableAnimations ? progress : 1) *
            closingContentOpacity,
        child: Flow(
          delegate: _CLSubmenuContentFlowDelegate(
            targetSize: page.targetRect!.size,
            initialOffset: Offset(
              -page.padding.left - 1,
              -page.padding.top - 1,
            ),
            progress: _disableAnimations ? 1 : progress,
          ),
          children: [_buildSubmenuContent(page, measuring: false)],
        ),
      ),
    );
  }

  Widget _buildSubmenuContent(
    _CLMenuPageEntry page, {
    required bool measuring,
  }) {
    final bodyOpacity = _disableAnimations
        ? 1.0
        : Interval(
            0.18,
            1,
            curve: Curves.easeOutCubic,
          ).transform(page.progress.value.clamp(0.0, 1.0).toDouble());
    final height = measuring ? null : page.targetRect?.height;
    return KeyedSubtree(
      key: page.contentKey,
      child: _SizeReporter(
        onSizeChanged: (size) => _handleSubmenuSize(page, size),
        child: SizedBox(
          width: page.targetWidth,
          height: height,
          child: Padding(
            padding: page.padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CLMenuSubmenuRow(
                  definition: page.definition,
                  focusNode: page.headerFocusNode,
                  progress: _disableAnimations ? 1 : page.progress.value,
                  expanded: true,
                  showLeading: !measuring,
                  onPressed: () => _popSubmenu(page),
                ),
                const CLDivider(),
                Flexible(
                  fit: FlexFit.loose,
                  child: Opacity(opacity: bodyOpacity, child: page.body),
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
    final width = ui.lerpDouble(_collapsedWidth, _expandedWidth, tMorph)!;
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
    final width = ui.lerpDouble(_collapsedWidth, _expandedWidth, tMorph)!;
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

    final matrix = _computeMenuMorphMatrix(width, height);

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
                child: Transform(
                  transform: matrix,
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
                          opacity: (opacity * _submenuContentOpacityForPage(0))
                              .clamp(0.0, 1.0)
                              .toDouble(),
                          child: Flow(
                            delegate: _CLMenuContentFlowDelegate(
                              targetWidth: _expandedWidth,
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
      ),
    );
  }

  Matrix4 _computeMenuMorphMatrix(double width, double height) {
    final tMorph = _morphProgress;
    if (tMorph <= 0.001 || tMorph >= 0.999) return Matrix4.identity();

    final clampedProgress = tMorph.clamp(0.0, 1.0);
    // Dynamic 3D perspective trapezoid skew during mid-flight morphing
    final factor = math.sin(clampedProgress * math.pi);

    final skewX = 0.0003 * factor * (_anchor.x > 0 ? -1.0 : 1.0);
    final skewY = 0.0004 * factor * (_growDown ? 1.0 : -1.0);

    return Matrix4.identity()
      ..setEntry(3, 0, skewX)
      ..setEntry(3, 1, skewY);
  }

  Widget _buildMeasuredList({required double maxHeight}) {
    return SizedBox(
      width: _expandedWidth,
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

class _CLMenuScope extends InheritedWidget {
  const _CLMenuScope({
    required this.state,
    required this.revision,
    required super.child,
  });

  final _CLMenuState state;
  final int revision;

  static _CLMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CLMenuScope>();

  Size? placeholderSizeFor(Object identity) {
    for (final page in state._submenuPages.reversed) {
      if (page.started && identical(page.sourceIdentity, identity)) {
        return page.placeholderSize;
      }
    }
    return null;
  }

  void updateSubmenuDefinition(
    Object identity,
    _CLMenuSubmenuDefinition definition,
  ) {
    state._updateSubmenuDefinition(identity, definition);
  }

  void openSubmenu({
    required Object identity,
    required GlobalKey triggerKey,
    required FocusNode returnFocusNode,
    required _CLMenuSubmenuDefinition definition,
  }) {
    state._openSubmenu(
      identity: identity,
      triggerKey: triggerKey,
      returnFocusNode: returnFocusNode,
      definition: definition,
    );
  }

  @override
  bool updateShouldNotify(_CLMenuScope oldWidget) =>
      revision != oldWidget.revision;
}

class _CLMenuSubmenuDefinition {
  const _CLMenuSubmenuDefinition({
    required this.label,
    required this.children,
    required this.leading,
    required this.tint,
    required this.size,
    required this.labelMaxLines,
  });

  factory _CLMenuSubmenuDefinition.fromWidget(CLMenuSubmenu widget) =>
      _CLMenuSubmenuDefinition(
        label: widget.label,
        children: widget.children,
        leading: widget.leading,
        tint: widget.tint,
        size: widget.size,
        labelMaxLines: widget.labelMaxLines,
      );

  final String label;
  final List<Widget> children;
  final Widget? leading;
  final Color? tint;
  final CLControlSize size;
  final int? labelMaxLines;

  bool matches(_CLMenuSubmenuDefinition other) =>
      label == other.label &&
      identical(children, other.children) &&
      identical(leading, other.leading) &&
      tint == other.tint &&
      size == other.size &&
      labelMaxLines == other.labelMaxLines;
}

class _CLMenuSubmenuRow extends StatelessWidget {
  const _CLMenuSubmenuRow({
    required this.definition,
    required this.focusNode,
    required this.progress,
    this.onPressed,
    this.expanded = false,
    this.showLeading = true,
  });

  final _CLMenuSubmenuDefinition definition;
  final FocusNode focusNode;
  final double progress;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    final chevronColor = CLTheme.of(context).colors.textHint;
    return FocusableActionDetector(
      enabled: onPressed != null,
      focusNode: focusNode,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: onPressed != null,
        expanded: expanded,
        label: definition.label,
        child: ExcludeSemantics(
          child: CLListTile(
            label: definition.label,
            leading: showLeading ? definition.leading : null,
            tint: definition.tint,
            size: definition.size,
            labelMaxLines: definition.labelMaxLines,
            trailing: definition.children.isEmpty
                ? null
                : SizedBox.square(
                    dimension: 16,
                    child: Center(
                      child: Transform.rotate(
                        angle: math.pi / 2 * progress.clamp(0.0, 1.0),
                        child: CustomPaint(
                          size: const Size(7, 12),
                          painter: _CLMenuSubmenuChevronPainter(chevronColor),
                        ),
                      ),
                    ),
                  ),
            onTap: onPressed,
          ),
        ),
      ),
    );
  }
}

class _CLMenuSubmenuChevronPainter extends CustomPainter {
  const _CLMenuSubmenuChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(0.5, 0.5)
        ..lineTo(size.width - 0.5, size.height / 2)
        ..lineTo(0.5, size.height - 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CLMenuSubmenuChevronPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _CLMenuPageEntry {
  _CLMenuPageEntry({
    required this.generation,
    required this.sourceIdentity,
    required _CLMenuSubmenuDefinition definition,
    required this.sourceRect,
    required this.placeholderSize,
    required this.safeRect,
    required this.padding,
    required this.targetWidth,
    required this.returnFocusNode,
    required this.progress,
    required this.onProgressTick,
  }) : _definition = definition {
    body = _buildBody(definition);
  }

  int generation;
  final Object sourceIdentity;
  _CLMenuSubmenuDefinition _definition;
  late Widget body;

  _CLMenuSubmenuDefinition get definition => _definition;

  set definition(_CLMenuSubmenuDefinition value) {
    _definition = value;
    body = _buildBody(value);
  }

  static Widget _buildBody(_CLMenuSubmenuDefinition definition) => CLList(
    shrinkWrap: true,
    physics: const ClampingScrollPhysics(),
    children: definition.children,
  );
  final Rect sourceRect;
  final Size placeholderSize;
  final Rect safeRect;
  final EdgeInsets padding;
  final double targetWidth;
  final FocusNode returnFocusNode;
  final AnimationController progress;
  final VoidCallback onProgressTick;
  final FocusNode headerFocusNode = FocusNode(
    debugLabel: 'CLMenuSubmenu header',
  );
  final GlobalKey contentKey = GlobalKey();
  Rect? targetRect;
  bool started = false;

  void dispose() {
    progress
      ..removeListener(onProgressTick)
      ..dispose();
    headerFocusNode.dispose();
  }
}

class _CLSubmenuContentFlowDelegate extends FlowDelegate {
  const _CLSubmenuContentFlowDelegate({
    required this.targetSize,
    required this.initialOffset,
    required this.progress,
  });

  final Size targetSize;
  final Offset initialOffset;
  final double progress;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(targetSize);

  @override
  void paintChildren(FlowPaintingContext context) {
    final offset = Offset.lerp(initialOffset, Offset.zero, progress)!;
    context.paintChild(
      0,
      transform: Matrix4.identity()
        ..translateByDouble(offset.dx, offset.dy, 0, 1),
    );
  }

  @override
  bool shouldRelayout(_CLSubmenuContentFlowDelegate oldDelegate) =>
      targetSize != oldDelegate.targetSize;

  @override
  bool shouldRepaint(_CLSubmenuContentFlowDelegate oldDelegate) =>
      initialOffset != oldDelegate.initialOffset ||
      progress != oldDelegate.progress;
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
