import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A source anchor for a [CLDialog] transition.
///
/// [capture] snapshots the entrance bounds and remeasures the same context when
/// dismissal starts. If that context has been disposed, the dialog dismisses
/// in place. [fixed] keeps a geometry-only anchor for both directions.
class CLDialogTrigger {
  CLDialogTrigger._(this.initialRect, this._rectResolver);

  factory CLDialogTrigger.capture(BuildContext context) {
    Rect? resolve() => _dialogTriggerRect(context);
    return CLDialogTrigger._(resolve(), resolve);
  }

  const CLDialogTrigger.fixed(Rect? rect)
    : initialRect = rect,
      _rectResolver = null;

  final Rect? initialRect;
  final Rect? Function()? _rectResolver;

  Rect? _resolveForDismissal() =>
      _rectResolver == null ? initialRect : _rectResolver();
}

/// A Claralight modal dialog — the "导出表盘" dialog of the design source.
///
/// A large-radius (36) translucent panel with a centered [title], free-form
/// [child] content and bottom [actions]. One or two actions share a row;
/// three or more actions stack vertically. Present it with [CLDialog.show].
class CLDialog extends StatelessWidget {
  /// Centered dialog title ("导出表盘").
  final String? title;

  /// Dialog body.
  final Widget child;

  /// Bottom action buttons. One or two share a row; three or more stack.
  final List<Widget> actions;

  /// Maximum dialog width.
  final double maxWidth;

  const CLDialog({
    super.key,
    this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 320,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CLSurface(
        // The design's dialog is a frosted raised layer: backdrop blur with
        // a control-tinted wash so it reads one step lighter than the
        // dimmed page behind it.
        frosted: true,
        fill: Color.alphaBlend(theme.colors.control, theme.colors.frost),
        borderRadius: BorderRadius.circular(theme.radii.dialog),
        outlined: true,
        shadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 62,
            spreadRadius: 17,
            offset: Offset(0, 4),
          ),
        ],
        padding: const EdgeInsets.all(14),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(CLThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) _buildTitle(theme),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DefaultTextStyle(
              style: theme.typography.body
                  .withCLWeight(FontWeight.w400)
                  .copyWith(color: theme.colors.textPrimary),
              textAlign: TextAlign.center,
              child: child,
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(height: 4), _buildActions()],
      ],
    );
  }

  Widget _buildTitle(CLThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Text(
        title!,
        textAlign: TextAlign.center,
        style: theme.typography.title.copyWith(color: theme.colors.textPrimary),
      ),
    );
  }

  Widget _buildActions() {
    if (actions.length >= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            actions[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }

  /// Presents a [CLDialog] centered over a scrim. The dialog uses the
  /// 4-corner perspective trapezoid morph animation unless reduced motion is
  /// enabled, in which case it remains centered and only fades. A dynamic
  /// [trigger] is measured again when dismissal starts so the dialog follows a
  /// moved source and ignores one that has been removed.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget> actions = const [],
    double maxWidth = 320,
    bool barrierDismissible = true,
    CLDialogTrigger? trigger,
  }) {
    final platformAnimationsDisabled = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final animationsDisabled =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        platformAnimationsDisabled;

    return Navigator.of(context, rootNavigator: true).push<T>(
      _CLDialogRoute<T>(
        builder: (context) => CLDialog(
          title: title,
          actions: actions,
          maxWidth: maxWidth,
          child: child,
        ),
        barrierDismissible: barrierDismissible,
        scrim: CLTheme.of(context).colors.scrim,
        trigger: trigger,
        animationsDisabled: animationsDisabled,
      ),
    );
  }
}

Rect? _dialogTriggerRect(BuildContext context) {
  if (!context.mounted) return null;
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
    return null;
  }
  return renderBox.localToGlobal(Offset.zero) & renderBox.size;
}

class _CLDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final Color scrim;
  final CLDialogTrigger? _trigger;
  Rect? _activeTriggerRect;
  bool _animationsDisabled;
  AnimationStatus _reducedFadeDirection;
  double _reducedFadeStartT = 0;
  double _reducedScrimStartOpacity = 0;
  double _reducedContentStartOpacity = 0;
  late final _CLDialogAccessibilityObserver _accessibilityObserver;

  _CLDialogRoute({
    required this.builder,
    required bool barrierDismissible,
    required this.scrim,
    required bool animationsDisabled,
    required CLDialogTrigger? trigger,
  }) : _barrierDismissible = barrierDismissible,
       _trigger = trigger,
       _activeTriggerRect = trigger?.initialRect,
       _animationsDisabled = animationsDisabled,
       _reducedFadeDirection = animationsDisabled
           ? AnimationStatus.forward
           : AnimationStatus.dismissed;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => _animationsDisabled
      ? CLMotion.reducedFade
      : const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration =>
      _animationsDisabled ? CLMotion.reducedFade : CLMotion.standard;

  @override
  AnimationController createAnimationController() {
    final routeController = AnimationController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
      // Reduced motion deliberately retains a short opacity transition.
      animationBehavior: AnimationBehavior.preserve,
    );
    routeController.addStatusListener(_handleTransitionStatus);
    return routeController;
  }

  @override
  void install() {
    super.install();
    _accessibilityObserver = _CLDialogAccessibilityObserver(
      _handleAccessibilityFeaturesChanged,
    );
    WidgetsBinding.instance.addObserver(_accessibilityObserver);
  }

  void _handleAccessibilityFeaturesChanged() {
    final platformAnimationsDisabled = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (platformAnimationsDisabled && _enableReducedMotion()) {
      changedExternalState();
    }
  }

  double _normalScrimOpacity(double t) =>
      Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));

  double _normalContentOpacity(double t) =>
      Curves.easeOut.transform((t / 0.35).clamp(0.0, 1.0));

  double _reducedFadeProgress(double t) {
    return switch (_reducedFadeDirection) {
      AnimationStatus.forward =>
        _reducedFadeStartT >= 1
            ? 1
            : ((t - _reducedFadeStartT) / (1 - _reducedFadeStartT)).clamp(
                0.0,
                1.0,
              ),
      AnimationStatus.reverse =>
        _reducedFadeStartT <= 0
            ? 1
            : ((_reducedFadeStartT - t) / _reducedFadeStartT).clamp(0.0, 1.0),
      AnimationStatus.completed || AnimationStatus.dismissed => 1,
    };
  }

  double _reducedOpacity(double t, double startOpacity) {
    final target = switch (_reducedFadeDirection) {
      AnimationStatus.forward || AnimationStatus.completed => 1.0,
      AnimationStatus.reverse || AnimationStatus.dismissed => 0.0,
    };
    final progress = CLMotion.easeOut.transform(_reducedFadeProgress(t));
    return startOpacity + (target - startOpacity) * progress;
  }

  bool _enableReducedMotion() {
    if (_animationsDisabled) return false;
    final routeController = controller;
    if (routeController == null) return false;
    final t = routeController.value;
    final scrimOpacity = _normalScrimOpacity(t);
    final contentOpacity = _normalContentOpacity(t);
    _animationsDisabled = true;
    _beginReducedFade(
      routeController.status,
      t: t,
      scrimOpacity: scrimOpacity,
      contentOpacity: contentOpacity,
    );
    routeController
      ..duration = CLMotion.reducedFade
      ..reverseDuration = CLMotion.reducedFade;
    switch (routeController.status) {
      case AnimationStatus.forward:
        routeController.animateTo(1, duration: CLMotion.reducedFade);
        break;
      case AnimationStatus.reverse:
        routeController.animateBack(0, duration: CLMotion.reducedFade);
        break;
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        break;
    }
    return true;
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && _trigger != null) {
      // The entrance rect is only a snapshot. Refresh it at dismissal so a
      // moved source remains connected, while a disposed source (such as a
      // closed menu item) no longer attracts the reverse morph.
      _activeTriggerRect = _trigger._resolveForDismissal();
      changedInternalState();
    }
    if (!_animationsDisabled) return;
    final t = controller?.value ?? 0;
    _beginReducedFade(status, t: t);
  }

  void _beginReducedFade(
    AnimationStatus direction, {
    required double t,
    double? scrimOpacity,
    double? contentOpacity,
  }) {
    _reducedScrimStartOpacity =
        scrimOpacity ?? _reducedOpacity(t, _reducedScrimStartOpacity);
    _reducedContentStartOpacity =
        contentOpacity ?? _reducedOpacity(t, _reducedContentStartOpacity);
    _reducedFadeStartT = t;
    _reducedFadeDirection = direction;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final inheritedAnimationsDisabled =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (inheritedAnimationsDisabled && !_animationsDisabled) {
          // Once requested, keep reduced motion for this route so geometry is
          // never reintroduced halfway through a transition.
          _enableReducedMotion();
        }
        final scrimOpacity = _animationsDisabled
            ? _reducedOpacity(t, _reducedScrimStartOpacity)
            : _normalScrimOpacity(t);
        final contentOpacity = _animationsDisabled
            ? _reducedOpacity(t, _reducedContentStartOpacity)
            : _normalContentOpacity(t);
        final dialog = Padding(
          padding: MediaQuery.paddingOf(context),
          child: Opacity(opacity: contentOpacity, child: builder(context)),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            ModalBarrier(
              color: scrim.withValues(alpha: scrim.a * scrimOpacity),
              dismissible: _barrierDismissible,
              semanticsLabel: barrierLabel,
            ),
            if (_animationsDisabled)
              Center(child: dialog)
            else
              _CLDialogMorphWidget(
                progress: t,
                triggerRect: _activeTriggerRect,
                child: dialog,
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_accessibilityObserver);
    controller?.removeStatusListener(_handleTransitionStatus);
    super.dispose();
  }
}

class _CLDialogAccessibilityObserver with WidgetsBindingObserver {
  _CLDialogAccessibilityObserver(this.onAccessibilityFeaturesChanged);

  final VoidCallback onAccessibilityFeaturesChanged;

  @override
  void didChangeAccessibilityFeatures() => onAccessibilityFeaturesChanged();
}

class _CLDialogMorphWidget extends SingleChildRenderObjectWidget {
  final double progress;
  final Rect? triggerRect;

  const _CLDialogMorphWidget({
    required this.progress,
    this.triggerRect,
    required super.child,
  });

  @override
  _RenderCLDialogMorph createRenderObject(BuildContext context) {
    return _RenderCLDialogMorph(progress: progress, triggerRect: triggerRect);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCLDialogMorph renderObject,
  ) {
    renderObject
      ..progress = progress
      ..triggerRect = triggerRect;
  }
}

class _RenderCLDialogMorph extends RenderProxyBox {
  double _progress;
  Rect? _triggerRect;
  Matrix4? _lastTransformMatrix;

  _RenderCLDialogMorph({
    required double progress,
    Rect? triggerRect,
    RenderBox? child,
  }) : _progress = progress,
       _triggerRect = triggerRect,
       super(child);

  double get progress => _progress;
  set progress(double value) {
    if (_progress != value) {
      _progress = value;
      markNeedsPaint();
    }
  }

  Rect? get triggerRect => _triggerRect;
  set triggerRect(Rect? value) {
    if (_triggerRect != value) {
      _triggerRect = value;
      markNeedsPaint();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(
        BoxConstraints(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
        ),
        parentUsesSize: true,
      );
      size = constraints.biggest;
    } else {
      size = constraints.biggest;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final childSize = child!.size;
    final targetCenter = Offset(size.width / 2, size.height / 2);
    final targetRect = Rect.fromCenter(
      center: targetCenter,
      width: childSize.width,
      height: childSize.height,
    );

    final origin = attached ? localToGlobal(Offset.zero) : Offset.zero;
    final startRect = _triggerRect != null
        ? _triggerRect!.shift(-origin)
        : Rect.fromCenter(
            center: targetCenter,
            width: childSize.width * 0.3,
            height: childSize.height * 0.3,
          );

    final p1Start = startRect.topLeft;
    final p2Start = startRect.topRight;
    final p3Start = startRect.bottomLeft;
    final p4Start = startRect.bottomRight;

    final p1End = targetRect.topLeft;
    final p2End = targetRect.topRight;
    final p3End = targetRect.bottomLeft;
    final p4End = targetRect.bottomRight;

    final d1 = (p1End - p1Start).distance;
    final d2 = (p2End - p2Start).distance;
    final d3 = (p3End - p3Start).distance;
    final d4 = (p4End - p4Start).distance;
    final maxD = [d1, d2, d3, d4, 1.0].reduce(math.max);

    final clampedProgress = _progress.clamp(0.0, 1.0);

    // Dynamic 4-corner perspective easing curves (Cubic Bezier).
    // Corners with larger displacement move with strong initial acceleration,
    // creating dynamic trapezoidal perspective deformation during morphing.
    double getCornerT(double d) {
      final ratio = (d / maxD).clamp(0.0, 1.0);
      final x1 = 0.35 - 0.20 * ratio;
      final y1 = 0.0 + 0.85 * ratio;
      final x2 = 0.45 - 0.20 * ratio;
      const y2 = 1.0;
      return Cubic(x1, y1, x2, y2).transform(clampedProgress);
    }

    final s1 = getCornerT(d1);
    final s2 = getCornerT(d2);
    final s3 = getCornerT(d3);
    final s4 = getCornerT(d4);

    // Direct 4-corner trajectory vectors:
    // At t = 0 (s_i = 0), current corners equal startRect 1:1.
    // At t = 1 (s_i = 1), current corners equal targetRect 1:1.
    final p1Current = Offset(
      p1Start.dx + (p1End.dx - p1Start.dx) * s1,
      p1Start.dy + (p1End.dy - p1Start.dy) * s1,
    );
    final p2Current = Offset(
      p2Start.dx + (p2End.dx - p2Start.dx) * s2,
      p2Start.dy + (p2End.dy - p2Start.dy) * s2,
    );
    final p3Current = Offset(
      p3Start.dx + (p3End.dx - p3Start.dx) * s3,
      p3Start.dy + (p3End.dy - p3Start.dy) * s3,
    );
    final p4Current = Offset(
      p4Start.dx + (p4End.dx - p4Start.dx) * s4,
      p4Start.dy + (p4End.dy - p4Start.dy) * s4,
    );

    final transformMatrix = _computeHomography(
      childSize,
      p1Current,
      p2Current,
      p3Current,
      p4Current,
    );
    _lastTransformMatrix = transformMatrix;

    final matrix = Matrix4.translationValues(offset.dx, offset.dy, 0.0)
      ..multiply(transformMatrix);

    context.pushTransform(needsCompositing, offset, matrix, (context, offset) {
      context.paintChild(child!, Offset.zero);
    });
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    assert(child == this.child);
    final transformMatrix = _lastTransformMatrix;
    if (transformMatrix != null) transform.multiply(transformMatrix);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    final transformMatrix = _lastTransformMatrix;
    if (transformMatrix == null) return false;
    return result.addWithPaintTransform(
      transform: transformMatrix,
      position: position,
      hitTest: (result, localPosition) {
        return child!.hitTest(result, position: localPosition);
      },
    );
  }

  static Matrix4 _computeHomography(
    Size childSize,
    Offset p1,
    Offset p2,
    Offset p3,
    Offset p4,
  ) {
    final w = childSize.width;
    final h = childSize.height;
    if (w <= 0 || h <= 0) return Matrix4.identity();

    final x1 = p1.dx, y1 = p1.dy;
    final x2 = p2.dx, y2 = p2.dy;
    final x3 = p3.dx, y3 = p3.dy;
    final x4 = p4.dx, y4 = p4.dy;

    final m03 = x1;
    final m13 = y1;

    final c = x4 - x2 - x3 + x1;
    final f = y4 - y2 - y3 + y1;

    final a = (x2 - x4) * w;
    final b = (x3 - x4) * h;
    final d = (y2 - y4) * w;
    final e = (y3 - y4) * h;

    final det = a * e - b * d;

    double m30 = 0.0;
    double m31 = 0.0;

    if (det.abs() > 1e-6) {
      m30 = (c * e - b * f) / det;
      m31 = (a * f - c * d) / det;
    }

    final m00 = (x2 - x1 + m30 * w * x2) / w;
    final m10 = (y2 - y1 + m30 * w * y2) / w;
    final m01 = (x3 - x1 + m31 * h * x3) / h;
    final m11 = (y3 - y1 + m31 * h * y3) / h;

    final matrix = Matrix4.identity();
    matrix.storage[0] = m00;
    matrix.storage[1] = m10;
    matrix.storage[3] = m30;
    matrix.storage[4] = m01;
    matrix.storage[5] = m11;
    matrix.storage[7] = m31;
    matrix.storage[12] = m03;
    matrix.storage[13] = m13;
    matrix.storage[15] = 1.0;

    return matrix;
  }
}
