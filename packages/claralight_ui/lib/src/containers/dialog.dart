import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: theme.typography.title.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
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
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 4),
              if (actions.length >= 3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      actions[i],
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Presents a [CLDialog] centered over a scrim, popping in with the
  /// 4-corner perspective trapezoid morph animation.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget> actions = const [],
    double maxWidth = 320,
    bool barrierDismissible = true,
    BuildContext? triggerContext,
    Rect? triggerRect,
  }) {
    Rect? resolvedTriggerRect = triggerRect;
    if (resolvedTriggerRect == null && triggerContext != null) {
      final renderBox = triggerContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.attached) {
        resolvedTriggerRect =
            renderBox.localToGlobal(Offset.zero) & renderBox.size;
      }
    }

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
        triggerRect: resolvedTriggerRect,
      ),
    );
  }
}

class _CLDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final Color scrim;
  final Rect? triggerRect;

  _CLDialogRoute({
    required this.builder,
    required bool barrierDismissible,
    required this.scrim,
    this.triggerRect,
  }) : _barrierDismissible = barrierDismissible;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => CLMotion.standard;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.4, curve: Curves.easeOut),
            reverseCurve: Curves.easeOut,
          ),
          child: ModalBarrier(
            color: scrim,
            dismissible: _barrierDismissible,
          ),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            // Fast content fade-in (0.0 to 0.35) so content becomes visible immediately.
            final contentOpacity = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
              reverseCurve: Curves.easeIn,
            ).value;

            return _CLDialogMorphWidget(
              progress: t,
              triggerRect: triggerRect,
              child: SafeArea(
                child: Opacity(
                  opacity: contentOpacity,
                  child: builder(context),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
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
    return _RenderCLDialogMorph(
      progress: progress,
      triggerRect: triggerRect,
    );
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
  })  : _progress = progress,
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

    context.pushTransform(
      needsCompositing,
      offset,
      matrix,
      (context, offset) {
        context.paintChild(child!, Offset.zero);
      },
    );
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
