import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A Claralight modal dialog — the "导出表盘" dialog of the design source.
///
/// A large-radius (36) translucent panel with a centered [title], free-form
/// [child] content and a bottom row of [actions] that share the width
/// equally. Present it with [CLDialog.show].
class CLDialog extends StatelessWidget {
  /// Centered dialog title ("导出表盘").
  final String? title;

  /// Dialog body.
  final Widget child;

  /// Bottom action buttons, laid out in one equally-divided row.
  final List<Widget> actions;

  /// Maximum dialog width.
  final double maxWidth;

  const CLDialog({
    super.key,
    this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 536,
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
                  style: theme.typography.title
                      .copyWith(color: theme.colors.textPrimary),
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
  /// Claralight spring.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget> actions = const [],
    double maxWidth = 536,
    bool barrierDismissible = true,
  }) {
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
      ),
    );
  }
}

class _CLDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final Color scrim;

  _CLDialogRoute({
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
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final scale = CurvedAnimation(
      parent: animation,
      curve: const _SpringOutCurve(),
      // Accelerating shrink on the way out; the fade below spans the whole
      // reverse so the dialog melts instead of hanging and blinking off.
      reverseCurve: Curves.easeIn,
    );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.4, curve: Curves.easeOut),
              reverseCurve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(scale),
              child: builder(context),
            ),
          ),
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
