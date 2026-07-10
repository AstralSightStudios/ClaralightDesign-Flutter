import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A Claralight bottom sheet — the dark sheet of the mobile mockup.
///
/// A panel-level surface with large top radii and a grabber. Use inline
/// (e.g. persistently docked like the mockup) or present it with
/// [CLSheet.show].
class CLSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Whether the drag grabber is shown.
  final bool showGrabber;

  const CLSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.showGrabber = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius = Radius.circular(theme.radii.sheet);

    return CLSurface(
      frosted: true,
      borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
      outlined: true,
      outlineColor: theme.colors.outlineStrong,
      shadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 32,
          offset: Offset(0, -8),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showGrabber)
            Center(
              child: Container(
                width: 63,
                height: 5,
                margin: const EdgeInsets.only(top: 8),
                decoration: clSmoothDecoration(
                  color: theme.colors.textHint,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          Flexible(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }

  /// Presents [child] as a modal sheet sliding up from the bottom with the
  /// Claralight spring.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool showGrabber = true,
    bool barrierDismissible = true,
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      _CLSheetRoute<T>(
        builder: (context) => CLSheet(
          showGrabber: showGrabber,
          child: child,
        ),
        barrierDismissible: barrierDismissible,
        scrim: CLTheme.of(context).colors.scrim,
      ),
    );
  }
}

class _CLSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final Color scrim;

  _CLSheetRoute({
    required this.builder,
    required bool barrierDismissible,
    required this.scrim,
  }) : _barrierDismissible = barrierDismissible;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      // A touch of overshoot so the sheet lands with the Claralight spring.
      curve: const _SpringOutCurve(),
      reverseCurve: Curves.easeInCubic,
    );

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: builder(context),
        ),
      ),
    );
  }
}

/// Critically-damped-ish spring approximation with a small overshoot.
class _SpringOutCurve extends Curve {
  const _SpringOutCurve();

  @override
  double transformInternal(double t) {
    // Damped oscillation tuned for a single ~4% overshoot.
    const omega = 9.2;
    const zeta = 0.82;
    final decay = math.exp(-zeta * omega * t);
    final freq = omega * math.sqrt(1 - zeta * zeta);
    return 1 -
        decay *
            (math.cos(freq * t) + (zeta * omega / freq) * math.sin(freq * t));
  }
}
