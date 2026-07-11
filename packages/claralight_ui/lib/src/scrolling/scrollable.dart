import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

import '../theme/theme.dart';
import 'edge_effects.dart';
import 'scrollbar_overlay.dart';
import 'types.dart';

export 'types.dart';

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
    this.blurSigma = const EdgeInsets.all(5),
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
            return CLEdgeEffects(
              horizontalController: effectiveHorizontalController,
              verticalController: effectiveVerticalController,
              horizontalAxisDirection: _horizontalEnabled
                  ? horizontalDirection
                  : null,
              verticalAxisDirection: _verticalEnabled
                  ? AxisDirection.down
                  : null,
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
        result = CLScrollbarOverlay(
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
