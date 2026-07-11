import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

import '../theme/theme.dart';

/// Axes that a [CLScrollable] can scroll.
enum CLScrollDirection {
  /// Allows free diagonal scrolling in both axes.
  both,

  /// Allows horizontal scrolling only.
  horizontal,

  /// Allows vertical scrolling only.
  vertical,
}

/// Visibility policy for one of a [CLScrollable]'s scrollbars.
enum CLScrollbarVisibility {
  /// Never paints the scrollbar.
  hidden,

  /// Shows the scrollbar while hovered or scrolling, then fades it out.
  auto,

  /// Keeps the scrollbar visible whenever its axis can scroll.
  always,
}

bool _isFinite(EdgeInsets value) =>
    value.left.isFinite &&
    value.top.isFinite &&
    value.right.isFinite &&
    value.bottom.isFinite;

/// A one- or two-dimensional Claralight viewport.
///
/// Content approaching an edge with more scrollable content behind it is
/// progressively blurred and masked. Setting one side of [blurExtent] to zero
/// disables both effects on that physical side; [blurSigma] controls only the
/// blur strength. Enabled axes require bounded constraints.
///
/// Call [precache] before `runApp` to avoid the blur shader appearing one frame
/// late. When supplying controllers for both axes, they must be distinct.
class CLScrollable extends StatefulWidget {
  /// The single scrollable content widget.
  final Widget child;

  /// Axes in which [child] can move.
  final CLScrollDirection direction;

  /// Physical width of each edge effect after resolving text direction.
  final EdgeInsetsGeometry blurExtent;

  /// Maximum Gaussian sigma contributed by each physical edge.
  final EdgeInsetsGeometry blurSigma;

  /// Insets that move with [child] and contribute to its scroll extent.
  final EdgeInsetsGeometry padding;

  /// Visibility policy for the bottom horizontal scrollbar.
  final CLScrollbarVisibility horizontalScrollbar;

  /// Visibility policy for the right vertical scrollbar.
  final CLScrollbarVisibility verticalScrollbar;

  /// Optional controller for the horizontal axis.
  final ScrollController? horizontalController;

  /// Optional controller for the vertical axis.
  final ScrollController? verticalController;

  /// Circular clip applied to the viewport and its edge effects.
  final BorderRadius borderRadius;

  /// Creates a Claralight scrollable viewport.
  const CLScrollable({
    super.key,
    required this.child,
    this.direction = CLScrollDirection.both,
    this.blurExtent = const EdgeInsets.all(24),
    this.blurSigma = const EdgeInsets.all(16),
    this.padding = EdgeInsets.zero,
    this.horizontalScrollbar = CLScrollbarVisibility.auto,
    this.verticalScrollbar = CLScrollbarVisibility.auto,
    this.horizontalController,
    this.verticalController,
    this.borderRadius = BorderRadius.zero,
  }) : assert(
         horizontalController == null ||
             verticalController == null ||
             !identical(horizontalController, verticalController),
         'CLScrollable requires a separate ScrollController for each axis.',
       );

  /// Precaches the fragment shader used by the progressive edge blur.
  ///
  /// Invoke this after [WidgetsFlutterBinding.ensureInitialized] and before
  /// `runApp`.
  static Future<void> precache() => ProgressiveBlurWidget.precache();

  @override
  State<CLScrollable> createState() => _CLScrollableState();

  bool get _horizontalEnabled => direction != CLScrollDirection.vertical;
  bool get _verticalEnabled => direction != CLScrollDirection.horizontal;

  Widget _build(
    BuildContext context, {
    required ScrollController effectiveHorizontalController,
    required ScrollController effectiveVerticalController,
  }) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final resolvedBlurExtent = blurExtent.resolve(textDirection);
    final resolvedBlurSigma = blurSigma.resolve(textDirection);
    assert(
      resolvedBlurExtent.isNonNegative && _isFinite(resolvedBlurExtent),
      'CLScrollable blurExtent values must be finite and non-negative.',
    );
    assert(
      resolvedBlurSigma.isNonNegative && _isFinite(resolvedBlurSigma),
      'CLScrollable blurSigma values must be finite and non-negative.',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasRequiredBounds = switch (direction) {
          CLScrollDirection.both =>
            constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          CLScrollDirection.horizontal => constraints.hasBoundedWidth,
          CLScrollDirection.vertical => constraints.hasBoundedHeight,
        };
        assert(
          hasRequiredBounds,
          'CLScrollable requires bounded constraints on every enabled axis.',
        );

        final horizontalDirection = textDirection == TextDirection.rtl
            ? AxisDirection.left
            : AxisDirection.right;
        Widget result = TwoDimensionalScrollable(
          horizontalDetails: ScrollableDetails(
            direction: horizontalDirection,
            controller: effectiveHorizontalController,
            physics: _horizontalEnabled
                ? null
                : const NeverScrollableScrollPhysics(),
          ),
          verticalDetails: ScrollableDetails(
            direction: AxisDirection.down,
            controller: effectiveVerticalController,
            physics: _verticalEnabled
                ? null
                : const NeverScrollableScrollPhysics(),
          ),
          diagonalDragBehavior: DiagonalDragBehavior.free,
          viewportBuilder: (context, verticalOffset, horizontalOffset) {
            final scrollBehavior = ScrollConfiguration.of(context);
            final horizontalPosition = horizontalOffset as ScrollPosition;
            final verticalPosition = verticalOffset as ScrollPosition;
            return _CLEdgeEffects(
              horizontalPosition: horizontalPosition,
              verticalPosition: verticalPosition,
              horizontalAxisDirection: horizontalDirection,
              verticalAxisDirection: AxisDirection.down,
              horizontalEnabled: _horizontalEnabled,
              verticalEnabled: _verticalEnabled,
              blurExtent: resolvedBlurExtent,
              blurSigma: resolvedBlurSigma,
              borderRadius: borderRadius,
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ScrollIntent: CallbackAction<ScrollIntent>(
                    onInvoke: (intent) => _handleScrollIntent(
                      intent,
                      horizontalPosition: horizontalPosition,
                      verticalPosition: verticalPosition,
                      horizontalAxisDirection: horizontalDirection,
                      verticalAxisDirection: AxisDirection.down,
                    ),
                  ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) => _handlePointerSignal(
                    event,
                    horizontalPosition: horizontalPosition,
                    verticalPosition: verticalPosition,
                    horizontalAxisDirection: horizontalDirection,
                    verticalAxisDirection: AxisDirection.down,
                    horizontalEnabled: _horizontalEnabled,
                    verticalEnabled: _verticalEnabled,
                    pointerAxisModifiers: scrollBehavior.pointerAxisModifiers,
                  ),
                  child: _CLSingleChildViewport(
                    horizontalAxisDirection: horizontalDirection,
                    verticalAxisDirection: AxisDirection.down,
                    horizontalOffset: horizontalOffset,
                    verticalOffset: verticalOffset,
                    horizontalEnabled: _horizontalEnabled,
                    verticalEnabled: _verticalEnabled,
                    child: Padding(padding: padding, child: child),
                  ),
                ),
              ),
            );
          },
        );
        result = _CLScrollbarOverlay(
          horizontalController: effectiveHorizontalController,
          verticalController: effectiveVerticalController,
          horizontalVisibility: horizontalScrollbar,
          verticalVisibility: verticalScrollbar,
          thumbColor: CLTheme.of(context).colors.selection,
          child: result,
        );
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: result,
        );
      },
    );
  }

  Object? _handleScrollIntent(
    ScrollIntent intent, {
    required ScrollPosition horizontalPosition,
    required ScrollPosition verticalPosition,
    required AxisDirection horizontalAxisDirection,
    required AxisDirection verticalAxisDirection,
  }) {
    final horizontalIntent =
        axisDirectionToAxis(intent.direction) == Axis.horizontal;
    if ((horizontalIntent && !_horizontalEnabled) ||
        (!horizontalIntent && !_verticalEnabled)) {
      return null;
    }

    final position = horizontalIntent ? horizontalPosition : verticalPosition;
    if (!position.hasContentDimensions) return null;
    final axisDirection = horizontalIntent
        ? horizontalAxisDirection
        : verticalAxisDirection;
    final increment = switch (intent.type) {
      ScrollIncrementType.line => 50.0,
      ScrollIncrementType.page => position.viewportDimension * 0.8,
    };
    final delta = intent.direction == axisDirection ? increment : -increment;
    position.moveTo(
      position.pixels + delta,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
    return null;
  }

  void _handlePointerSignal(
    PointerSignalEvent event, {
    required ScrollPosition horizontalPosition,
    required ScrollPosition verticalPosition,
    required AxisDirection horizontalAxisDirection,
    required AxisDirection verticalAxisDirection,
    required bool horizontalEnabled,
    required bool verticalEnabled,
    required Set<LogicalKeyboardKey> pointerAxisModifiers,
  }) {
    if (event is! PointerScrollEvent) return;

    final flipAxes =
        event.kind == PointerDeviceKind.mouse &&
        HardwareKeyboard.instance.logicalKeysPressed.any(
          pointerAxisModifiers.contains,
        );
    final rawDelta = flipAxes
        ? Offset(event.scrollDelta.dy, event.scrollDelta.dx)
        : event.scrollDelta;
    final horizontalDelta = horizontalEnabled
        ? axisDirectionIsReversed(horizontalAxisDirection)
              ? -rawDelta.dx
              : rawDelta.dx
        : 0.0;
    final verticalDelta = verticalEnabled
        ? axisDirectionIsReversed(verticalAxisDirection)
              ? -rawDelta.dy
              : rawDelta.dy
        : 0.0;

    final canScrollHorizontal = _canPointerScroll(
      horizontalPosition,
      horizontalDelta,
    );
    final canScrollVertical = _canPointerScroll(
      verticalPosition,
      verticalDelta,
    );
    if (!canScrollHorizontal && !canScrollVertical) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scrollEvent = event as PointerScrollEvent;
      if (_canPointerScroll(horizontalPosition, horizontalDelta)) {
        horizontalPosition.pointerScroll(horizontalDelta);
      }
      if (_canPointerScroll(verticalPosition, verticalDelta)) {
        verticalPosition.pointerScroll(verticalDelta);
      }
      scrollEvent.respond(allowPlatformDefault: false);
    });
  }

  bool _canPointerScroll(ScrollPosition position, double delta) {
    if (delta == 0 || !position.hasContentDimensions) return false;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return target != position.pixels;
  }
}

class _CLScrollableState extends State<CLScrollable> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  late bool _ownsHorizontalController;
  late bool _ownsVerticalController;

  @override
  void initState() {
    super.initState();
    _setHorizontalController(widget.horizontalController);
    _setVerticalController(widget.verticalController);
  }

  @override
  void didUpdateWidget(covariant CLScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horizontalController != widget.horizontalController) {
      if (_ownsHorizontalController) _horizontalController.dispose();
      _setHorizontalController(widget.horizontalController);
    }
    if (oldWidget.verticalController != widget.verticalController) {
      if (_ownsVerticalController) _verticalController.dispose();
      _setVerticalController(widget.verticalController);
    }
  }

  void _setHorizontalController(ScrollController? controller) {
    _ownsHorizontalController = controller == null;
    _horizontalController = controller ?? ScrollController();
  }

  void _setVerticalController(ScrollController? controller) {
    _ownsVerticalController = controller == null;
    _verticalController = controller ?? ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return widget._build(
      context,
      effectiveHorizontalController: _horizontalController,
      effectiveVerticalController: _verticalController,
    );
  }

  @override
  void dispose() {
    if (_ownsHorizontalController) _horizontalController.dispose();
    if (_ownsVerticalController) _verticalController.dispose();
    super.dispose();
  }
}

class _CLScrollbarOverlay extends StatefulWidget {
  const _CLScrollbarOverlay({
    required this.horizontalController,
    required this.verticalController,
    required this.horizontalVisibility,
    required this.verticalVisibility,
    required this.thumbColor,
    required this.child,
  });

  final ScrollController horizontalController;
  final ScrollController verticalController;
  final CLScrollbarVisibility horizontalVisibility;
  final CLScrollbarVisibility verticalVisibility;
  final Color thumbColor;
  final Widget child;

  @override
  State<_CLScrollbarOverlay> createState() => _CLScrollbarOverlayState();
}

class _CLScrollbarOverlayState extends State<_CLScrollbarOverlay>
    with SingleTickerProviderStateMixin {
  static const _fadeInDuration = Duration(milliseconds: 160);
  static const _fadeOutDelay = Duration(seconds: 1);
  static const _fadeOutDuration = Duration(milliseconds: 300);

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
  void didUpdateWidget(covariant _CLScrollbarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horizontalController != widget.horizontalController ||
        oldWidget.verticalController != widget.verticalController) {
      oldWidget.horizontalController.removeListener(_handleControllerChanged);
      oldWidget.verticalController.removeListener(_handleControllerChanged);
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
    widget.horizontalController.addListener(_handleControllerChanged);
    widget.verticalController.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (_horizontalPosition == null || _verticalPosition == null) {
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
    final horizontal = widget.horizontalController.hasClients
        ? widget.horizontalController.position
        : null;
    final vertical = widget.verticalController.hasClients
        ? widget.verticalController.position
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
    _visibleTarget = true;
    if (_disableAnimations) {
      _opacity.value = 1;
    } else if (_opacity.value != 1 &&
        !(_opacity.isAnimating && _opacity.status == AnimationStatus.forward)) {
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
      _opacity.animateTo(
        0,
        duration: _fadeOutDuration,
        curve: Curves.easeInCubic,
      );
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
        if (widget.horizontalVisibility != CLScrollbarVisibility.hidden) {
          final opacity =
              widget.horizontalVisibility == CLScrollbarVisibility.always
              ? 1.0
              : _opacity.value;
          result = _buildRawScrollbar(
            axis: Axis.horizontal,
            controller: widget.horizontalController,
            thumbColor: widget.thumbColor.withValues(
              alpha: widget.thumbColor.a * opacity,
            ),
            interactive: opacity > 0,
            child: result,
          );
        }
        if (widget.verticalVisibility != CLScrollbarVisibility.hidden) {
          final opacity =
              widget.verticalVisibility == CLScrollbarVisibility.always
              ? 1.0
              : _opacity.value;
          result = _buildRawScrollbar(
            axis: Axis.vertical,
            controller: widget.verticalController,
            thumbColor: widget.thumbColor.withValues(
              alpha: widget.thumbColor.a * opacity,
            ),
            interactive: opacity > 0,
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
    widget.horizontalController.removeListener(_handleControllerChanged);
    widget.verticalController.removeListener(_handleControllerChanged);
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
  required Widget child,
}) {
  return RawScrollbar(
    controller: controller,
    thumbVisibility: true,
    interactive: interactive,
    thickness: 4,
    radius: const Radius.circular(17),
    thumbColor: thumbColor,
    minThumbLength: 49,
    trackVisibility: false,
    fadeDuration: Duration.zero,
    timeToFade: Duration.zero,
    mainAxisMargin: 2,
    scrollbarOrientation: axis == Axis.vertical
        ? ScrollbarOrientation.right
        : ScrollbarOrientation.bottom,
    padding: EdgeInsets.zero,
    notificationPredicate: (notification) =>
        notification.depth == 0 && notification.metrics.axis == axis,
    child: child,
  );
}

class _CLEdgeEffects extends StatefulWidget {
  const _CLEdgeEffects({
    required this.horizontalPosition,
    required this.verticalPosition,
    required this.horizontalAxisDirection,
    required this.verticalAxisDirection,
    required this.horizontalEnabled,
    required this.verticalEnabled,
    required this.blurExtent,
    required this.blurSigma,
    required this.borderRadius,
    required this.child,
  });

  final ScrollPosition horizontalPosition;
  final ScrollPosition verticalPosition;
  final AxisDirection horizontalAxisDirection;
  final AxisDirection verticalAxisDirection;
  final bool horizontalEnabled;
  final bool verticalEnabled;
  final EdgeInsets blurExtent;
  final EdgeInsets blurSigma;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_CLEdgeEffects> createState() => _CLEdgeEffectsState();
}

class _CLEdgeEffectsState extends State<_CLEdgeEffects>
    with TickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 160);
  static const _left = 0;
  static const _top = 1;
  static const _right = 2;
  static const _bottom = 3;

  late final List<AnimationController> _controllers;
  late final Listenable _animation;
  final List<bool> _targets = List<bool>.filled(4, false);
  bool _disableAnimations = false;
  bool _updateScheduled = false;
  ui.Image? _blurTexture;
  Size? _blurTextureSize;
  EdgeInsets? _blurTextureExtent;
  EdgeInsets? _blurTextureSigma;
  EdgeInsets? _blurTextureActivation;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (_) => AnimationController(vsync: this, duration: _transitionDuration),
    );
    _animation = Listenable.merge(_controllers);
    _addPositionListeners();
    _scheduleTargetUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      for (var index = 0; index < _controllers.length; index += 1) {
        _controllers[index].value = _targets[index] ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _CLEdgeEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horizontalPosition != widget.horizontalPosition ||
        oldWidget.verticalPosition != widget.verticalPosition) {
      oldWidget.horizontalPosition.removeListener(_updateTargets);
      oldWidget.verticalPosition.removeListener(_updateTargets);
      _addPositionListeners();
    }
    _scheduleTargetUpdate();
  }

  void _addPositionListeners() {
    widget.horizontalPosition.addListener(_updateTargets);
    widget.verticalPosition.addListener(_updateTargets);
  }

  void _scheduleTargetUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updateTargets();
    });
  }

  void _updateTargets() {
    final horizontal = widget.horizontalPosition;
    final vertical = widget.verticalPosition;
    if (!horizontal.hasContentDimensions || !vertical.hasContentDimensions) {
      return;
    }

    final horizontalBefore =
        horizontal.pixels >
        horizontal.minScrollExtent + precisionErrorTolerance;
    final horizontalAfter =
        horizontal.pixels <
        horizontal.maxScrollExtent - precisionErrorTolerance;
    final horizontalReversed = axisDirectionIsReversed(
      widget.horizontalAxisDirection,
    );
    _setTarget(
      _left,
      widget.horizontalEnabled &&
          widget.blurExtent.left > 0 &&
          (horizontalReversed ? horizontalAfter : horizontalBefore),
    );
    _setTarget(
      _right,
      widget.horizontalEnabled &&
          widget.blurExtent.right > 0 &&
          (horizontalReversed ? horizontalBefore : horizontalAfter),
    );

    final verticalBefore =
        vertical.pixels > vertical.minScrollExtent + precisionErrorTolerance;
    final verticalAfter =
        vertical.pixels < vertical.maxScrollExtent - precisionErrorTolerance;
    final verticalReversed = axisDirectionIsReversed(
      widget.verticalAxisDirection,
    );
    _setTarget(
      _top,
      widget.verticalEnabled &&
          widget.blurExtent.top > 0 &&
          (verticalReversed ? verticalAfter : verticalBefore),
    );
    _setTarget(
      _bottom,
      widget.verticalEnabled &&
          widget.blurExtent.bottom > 0 &&
          (verticalReversed ? verticalBefore : verticalAfter),
    );
  }

  void _setTarget(int index, bool target) {
    if (_targets[index] == target) return;
    _targets[index] = target;
    final controller = _controllers[index];
    if (_disableAnimations) {
      controller.value = target ? 1 : 0;
      return;
    }
    controller.animateTo(
      target ? 1 : 0,
      duration: _transitionDuration,
      curve: target ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final activation = EdgeInsets.fromLTRB(
          _controllers[_left].value,
          _controllers[_top].value,
          _controllers[_right].value,
          _controllers[_bottom].value,
        );
        Widget result = child!;
        final hasDimensions =
            widget.horizontalPosition.hasContentDimensions &&
            widget.verticalPosition.hasContentDimensions;
        if (activation != EdgeInsets.zero && hasDimensions) {
          final viewportSize = Size(
            widget.horizontalPosition.viewportDimension,
            widget.verticalPosition.viewportDimension,
          );
          final globalSigma = _globalSigma(widget.blurExtent, widget.blurSigma);
          if (globalSigma > 0 && !viewportSize.isEmpty) {
            final blurTexture = _getBlurTexture(
              viewportSize,
              extent: widget.blurExtent,
              sigma: widget.blurSigma,
              activation: activation,
              globalSigma: globalSigma,
            );
            result = ProgressiveBlurWidget.custom(
              sigma: globalSigma,
              blurTexture: blurTexture,
              child: result,
            );
          } else {
            _replaceBlurTexture(null);
          }
        } else {
          _replaceBlurTexture(null);
        }
        if (activation != EdgeInsets.zero) {
          result = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => _createMaskShader(
              bounds,
              extent: widget.blurExtent,
              activation: activation,
            ),
            child: result,
          );
        }
        if (widget.borderRadius != BorderRadius.zero) {
          result = ClipRRect(borderRadius: widget.borderRadius, child: result);
        }
        return result;
      },
    );
  }

  ui.Image _getBlurTexture(
    Size size, {
    required EdgeInsets extent,
    required EdgeInsets sigma,
    required EdgeInsets activation,
    required double globalSigma,
  }) {
    if (_blurTexture != null &&
        _blurTextureSize == size &&
        _blurTextureExtent == extent &&
        _blurTextureSigma == sigma &&
        _blurTextureActivation == activation) {
      return _blurTexture!;
    }

    _blurTextureSize = size;
    _blurTextureExtent = extent;
    _blurTextureSigma = sigma;
    _blurTextureActivation = activation;
    final texture = _createBlurTexture(
      size,
      extent: extent,
      sigma: sigma,
      activation: activation,
      globalSigma: globalSigma,
    );
    _replaceBlurTexture(texture);
    return texture;
  }

  void _replaceBlurTexture(ui.Image? texture) {
    if (identical(_blurTexture, texture)) return;
    final oldTexture = _blurTexture;
    _blurTexture = texture;
    if (texture == null) {
      _blurTextureSize = null;
      _blurTextureExtent = null;
      _blurTextureSigma = null;
      _blurTextureActivation = null;
    }
    if (oldTexture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldTexture.dispose());
    }
  }

  @override
  void dispose() {
    widget.horizontalPosition.removeListener(_updateTargets);
    widget.verticalPosition.removeListener(_updateTargets);
    for (final controller in _controllers) {
      controller.dispose();
    }
    _blurTexture?.dispose();
    _blurTexture = null;
    super.dispose();
  }
}

double _globalSigma(EdgeInsets extent, EdgeInsets sigma) {
  var result = 0.0;
  if (extent.left > 0) result = math.max(result, sigma.left);
  if (extent.top > 0) result = math.max(result, sigma.top);
  if (extent.right > 0) result = math.max(result, sigma.right);
  if (extent.bottom > 0) result = math.max(result, sigma.bottom);
  return result;
}

ui.Image _createBlurTexture(
  Size logicalSize, {
  required EdgeInsets extent,
  required EdgeInsets sigma,
  required EdgeInsets activation,
  required double globalSigma,
}) {
  final width = math.min(512, math.max(1, logicalSize.width.ceil()));
  final height = math.min(512, math.max(1, logicalSize.height.ceil()));
  final scaleX = width / logicalSize.width;
  final scaleY = height / logicalSize.height;
  final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xff000000), BlendMode.src);

  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(extent.left * scaleX, 0),
    activation: activation.left,
    sigma: sigma.left,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset(width.toDouble(), 0),
    end: Offset(width - extent.right * scaleX, 0),
    activation: activation.right,
    sigma: sigma.right,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(0, extent.top * scaleY),
    activation: activation.top,
    sigma: sigma.top,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset(0, height.toDouble()),
    end: Offset(0, height - extent.bottom * scaleY),
    activation: activation.bottom,
    sigma: sigma.bottom,
    globalSigma: globalSigma,
  );

  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

void _drawBlurGradient(
  Canvas canvas,
  Rect bounds, {
  required Offset start,
  required Offset end,
  required double activation,
  required double sigma,
  required double globalSigma,
}) {
  if (activation <= 0 || sigma <= 0 || start == end) return;
  const sampleCount = 16;
  final colors = <Color>[];
  final stops = <double>[];
  for (var sample = 0; sample <= sampleCount; sample += 1) {
    final position = sample / sampleCount;
    final smoothstep = position * position * (3 - 2 * position);
    final effectiveSigma = sigma * activation * (1 - smoothstep);
    final value = (255 * math.sqrt(effectiveSigma / globalSigma)).round();
    colors.add(Color.fromARGB(255, value, value, value));
    stops.add(position);
  }
  final paint = Paint()
    ..shader = ui.Gradient.linear(start, end, colors, stops, TileMode.clamp)
    ..blendMode = BlendMode.lighten;
  canvas.drawRect(bounds, paint);
}

ui.Shader _createMaskShader(
  Rect bounds, {
  required EdgeInsets extent,
  required EdgeInsets activation,
}) {
  final image = _createMaskTexture(bounds.size, extent, activation);
  final transform = Matrix4.diagonal3Values(
    bounds.width / image.width,
    bounds.height / image.height,
    1,
  )..setTranslationRaw(bounds.left, bounds.top, 0);
  final shader = ui.ImageShader(
    image,
    ui.TileMode.clamp,
    ui.TileMode.clamp,
    transform.storage,
    filterQuality: FilterQuality.low,
  );
  image.dispose();
  return shader;
}

ui.Image _createMaskTexture(
  Size logicalSize,
  EdgeInsets extent,
  EdgeInsets activation,
) {
  final width = math.min(512, math.max(1, logicalSize.width.ceil()));
  final height = math.min(512, math.max(1, logicalSize.height.ceil()));
  final scaleX = width / logicalSize.width;
  final scaleY = height / logicalSize.height;
  final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xffffffff), BlendMode.src);

  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(extent.left * scaleX, 0),
    activation: activation.left,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset(width.toDouble(), 0),
    end: Offset(width - extent.right * scaleX, 0),
    activation: activation.right,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(0, extent.top * scaleY),
    activation: activation.top,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset(0, height.toDouble()),
    end: Offset(0, height - extent.bottom * scaleY),
    activation: activation.bottom,
  );

  final picture = recorder.endRecording();
  final grayscale = picture.toImageSync(width, height);
  picture.dispose();

  final alphaRecorder = ui.PictureRecorder();
  final alphaCanvas = Canvas(alphaRecorder);
  final alphaPaint = Paint()
    ..colorFilter = const ColorFilter.matrix([
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      1,
      0,
      0,
      0,
      0,
    ]);
  alphaCanvas.drawImage(grayscale, Offset.zero, alphaPaint);
  final alphaPicture = alphaRecorder.endRecording();
  final image = alphaPicture.toImageSync(width, height);
  alphaPicture.dispose();
  grayscale.dispose();
  return image;
}

void _drawMaskGradient(
  Canvas canvas,
  Rect bounds, {
  required Offset start,
  required Offset end,
  required double activation,
}) {
  if (activation <= 0 || start == end) return;
  const sampleCount = 16;
  final colors = <Color>[];
  final stops = <double>[];
  for (var sample = 0; sample <= sampleCount; sample += 1) {
    final position = sample / sampleCount;
    final smoothstep = position * position * (3 - 2 * position);
    final value = (255 * (1 - activation * (1 - smoothstep))).round();
    colors.add(Color.fromARGB(255, value, value, value));
    stops.add(position);
  }
  final paint = Paint()
    ..shader = ui.Gradient.linear(start, end, colors, stops, TileMode.clamp)
    ..blendMode = BlendMode.darken;
  canvas.drawRect(bounds, paint);
}

class _CLSingleChildViewport extends SingleChildRenderObjectWidget {
  const _CLSingleChildViewport({
    required this.horizontalAxisDirection,
    required this.verticalAxisDirection,
    required this.horizontalOffset,
    required this.verticalOffset,
    required this.horizontalEnabled,
    required this.verticalEnabled,
    super.child,
  });

  final AxisDirection horizontalAxisDirection;
  final AxisDirection verticalAxisDirection;
  final ViewportOffset horizontalOffset;
  final ViewportOffset verticalOffset;
  final bool horizontalEnabled;
  final bool verticalEnabled;

  @override
  _RenderCLSingleChildViewport createRenderObject(BuildContext context) {
    return _RenderCLSingleChildViewport(
      horizontalAxisDirection: horizontalAxisDirection,
      verticalAxisDirection: verticalAxisDirection,
      horizontalOffset: horizontalOffset,
      verticalOffset: verticalOffset,
      horizontalEnabled: horizontalEnabled,
      verticalEnabled: verticalEnabled,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCLSingleChildViewport renderObject,
  ) {
    renderObject
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalAxisDirection = verticalAxisDirection
      ..horizontalOffset = horizontalOffset
      ..verticalOffset = verticalOffset
      ..horizontalEnabled = horizontalEnabled
      ..verticalEnabled = verticalEnabled;
  }

  @override
  SingleChildRenderObjectElement createElement() {
    return _CLSingleChildViewportElement(this);
  }
}

class _CLSingleChildViewportElement extends SingleChildRenderObjectElement
    with NotifiableElementMixin, ViewportElementMixin {
  _CLSingleChildViewportElement(_CLSingleChildViewport super.widget);
}

class _RenderCLSingleChildViewport extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>
    implements RenderAbstractViewport {
  _RenderCLSingleChildViewport({
    required AxisDirection horizontalAxisDirection,
    required AxisDirection verticalAxisDirection,
    required ViewportOffset horizontalOffset,
    required ViewportOffset verticalOffset,
    required bool horizontalEnabled,
    required bool verticalEnabled,
    RenderBox? child,
  }) : _horizontalAxisDirection = horizontalAxisDirection,
       _verticalAxisDirection = verticalAxisDirection,
       _horizontalOffset = horizontalOffset,
       _verticalOffset = verticalOffset,
       _horizontalEnabled = horizontalEnabled,
       _verticalEnabled = verticalEnabled {
    this.child = child;
  }

  AxisDirection get horizontalAxisDirection => _horizontalAxisDirection;
  AxisDirection _horizontalAxisDirection;
  set horizontalAxisDirection(AxisDirection value) {
    if (_horizontalAxisDirection == value) return;
    _horizontalAxisDirection = value;
    markNeedsLayout();
  }

  AxisDirection get verticalAxisDirection => _verticalAxisDirection;
  AxisDirection _verticalAxisDirection;
  set verticalAxisDirection(AxisDirection value) {
    if (_verticalAxisDirection == value) return;
    _verticalAxisDirection = value;
    markNeedsLayout();
  }

  ViewportOffset get horizontalOffset => _horizontalOffset;
  ViewportOffset _horizontalOffset;
  set horizontalOffset(ViewportOffset value) {
    if (_horizontalOffset == value) return;
    if (attached) _horizontalOffset.removeListener(_handleOffsetChanged);
    _horizontalOffset = value;
    if (attached) _horizontalOffset.addListener(_handleOffsetChanged);
    markNeedsLayout();
  }

  ViewportOffset get verticalOffset => _verticalOffset;
  ViewportOffset _verticalOffset;
  set verticalOffset(ViewportOffset value) {
    if (_verticalOffset == value) return;
    if (attached) _verticalOffset.removeListener(_handleOffsetChanged);
    _verticalOffset = value;
    if (attached) _verticalOffset.addListener(_handleOffsetChanged);
    markNeedsLayout();
  }

  bool get horizontalEnabled => _horizontalEnabled;
  bool _horizontalEnabled;
  set horizontalEnabled(bool value) {
    if (_horizontalEnabled == value) return;
    _horizontalEnabled = value;
    markNeedsLayout();
  }

  bool get verticalEnabled => _verticalEnabled;
  bool _verticalEnabled;
  set verticalEnabled(bool value) {
    if (_verticalEnabled == value) return;
    _verticalEnabled = value;
    markNeedsLayout();
  }

  void _handleOffsetChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    horizontalOffset.addListener(_handleOffsetChanged);
    verticalOffset.addListener(_handleOffsetChanged);
  }

  @override
  void detach() {
    horizontalOffset.removeListener(_handleOffsetChanged);
    verticalOffset.removeListener(_handleOffsetChanged);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  BoxConstraints _innerConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: horizontalEnabled ? double.infinity : constraints.maxWidth,
      maxHeight: verticalEnabled ? double.infinity : constraints.maxHeight,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    final childSize = child!.getDryLayout(_innerConstraints(constraints));
    return constraints.constrain(childSize);
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
    } else {
      child!.layout(_innerConstraints(constraints), parentUsesSize: true);
      size = constraints.constrain(child!.size);
    }

    final maxHorizontalExtent = horizontalEnabled && child != null
        ? math.max(0.0, child!.size.width - size.width)
        : 0.0;
    final maxVerticalExtent = verticalEnabled && child != null
        ? math.max(0.0, child!.size.height - size.height)
        : 0.0;

    _correctOffset(horizontalOffset, maxHorizontalExtent);
    _correctOffset(verticalOffset, maxVerticalExtent);
    horizontalOffset.applyViewportDimension(size.width);
    verticalOffset.applyViewportDimension(size.height);
    horizontalOffset.applyContentDimensions(0, maxHorizontalExtent);
    verticalOffset.applyContentDimensions(0, maxVerticalExtent);
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final position = horizontalOffset;
    if (!hasSize ||
        !horizontalEnabled ||
        position is! ScrollPosition ||
        !position.hasContentDimensions) {
      return;
    }

    final direction = axisDirectionIsReversed(horizontalAxisDirection)
        ? -1.0
        : 1.0;
    final leftDelta = size.width * 0.8 * direction;
    final rightDelta = -leftDelta;
    if (_canSemanticScroll(position, leftDelta)) {
      config.onScrollLeft = () => _semanticScroll(position, leftDelta);
    }
    if (_canSemanticScroll(position, rightDelta)) {
      config.onScrollRight = () => _semanticScroll(position, rightDelta);
    }
  }

  bool _canSemanticScroll(ScrollPosition position, double delta) {
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return target != position.pixels;
  }

  void _semanticScroll(ScrollPosition position, double delta) {
    position.moveTo(position.pixels + delta);
  }

  void _correctOffset(ViewportOffset offset, double maxExtent) {
    if (!offset.hasPixels) return;
    if (offset.pixels > maxExtent) {
      offset.correctBy(maxExtent - offset.pixels);
    } else if (offset.pixels < 0) {
      offset.correctBy(-offset.pixels);
    }
  }

  Offset get _paintOffset => _paintOffsetFor(
    horizontalPixels: horizontalOffset.pixels,
    verticalPixels: verticalOffset.pixels,
  );

  Offset _paintOffsetFor({
    required double horizontalPixels,
    required double verticalPixels,
  }) {
    if (child == null) return Offset.zero;
    final dx = switch (horizontalAxisDirection) {
      AxisDirection.left => horizontalPixels - child!.size.width + size.width,
      AxisDirection.right => -horizontalPixels,
      AxisDirection.up || AxisDirection.down => 0.0,
    };
    final dy = switch (verticalAxisDirection) {
      AxisDirection.up => verticalPixels - child!.size.height + size.height,
      AxisDirection.down => -verticalPixels,
      AxisDirection.left || AxisDirection.right => 0.0,
    };
    return Offset(dx, dy);
  }

  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    axis ??= Axis.vertical;
    final currentOffset = axis == Axis.horizontal
        ? horizontalOffset.pixels
        : verticalOffset.pixels;
    rect ??= target.paintBounds;
    if (child == null || target is! RenderBox) {
      return RevealedOffset(offset: currentOffset, rect: rect);
    }

    final bounds = MatrixUtils.transformRect(
      target.getTransformTo(child),
      rect,
    );
    final (viewportExtent, targetExtent, leadingOffset) = switch (axis) {
      Axis.horizontal => (
        size.width,
        bounds.width,
        horizontalAxisDirection == AxisDirection.left
            ? child!.size.width - bounds.right
            : bounds.left,
      ),
      Axis.vertical => (
        size.height,
        bounds.height,
        verticalAxisDirection == AxisDirection.up
            ? child!.size.height - bounds.bottom
            : bounds.top,
      ),
    };
    final targetOffset =
        leadingOffset - (viewportExtent - targetExtent) * alignment;
    final paintOffset = _paintOffsetFor(
      horizontalPixels: axis == Axis.horizontal
          ? targetOffset
          : horizontalOffset.pixels,
      verticalPixels: axis == Axis.vertical
          ? targetOffset
          : verticalOffset.pixels,
    );
    return RevealedOffset(
      offset: targetOffset,
      rect: bounds.shift(paintOffset),
    );
  }

  bool get _shouldClip {
    if (child == null) return false;
    final paintOffset = _paintOffset;
    return paintOffset.dx < 0 ||
        paintOffset.dy < 0 ||
        paintOffset.dx + child!.size.width > size.width ||
        paintOffset.dy + child!.size.height > size.height;
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    void paintChild(PaintingContext context, Offset offset) {
      context.paintChild(child!, offset + _paintOffset);
    }

    if (_shouldClip) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintChild,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      paintChild(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _paintOffset,
      position: position,
      hitTest: (result, transformed) =>
          child!.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final paintOffset = _paintOffset;
    transform.translateByDouble(paintOffset.dx, paintOffset.dy, 0, 1);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject? child) {
    return _shouldClip ? Offset.zero & size : null;
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }
}
