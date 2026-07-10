import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A small ClaraLight filled label — the "12px" measurement tags and the
/// blue "78x91px" size tag of the design's canvas.
///
/// Values render in the monospace family; a trailing [unit] renders dimmed,
/// like the design's `12` + `px` pairing.
class CLBadge extends StatelessWidget {
  final String label;

  /// Dimmed trailing unit, e.g. "px".
  final String? unit;

  /// Fill color. Defaults to the theme accent.
  final Color? color;

  /// Text color. Defaults to the theme's on-accent color.
  final Color? foreground;

  const CLBadge(
    this.label, {
    super.key,
    this.unit,
    this.color,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final fg = foreground ?? theme.colors.onAccent;
    final style = theme.typography.mono.copyWith(fontSize: 12, color: fg);

    return DecoratedBox(
      decoration: clSmoothDecoration(
        color: color ?? theme.colors.accent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        child: Text.rich(
          TextSpan(
            text: label,
            style: style,
            children: [
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: style.copyWith(
                    color: fg.withValues(alpha: fg.a * 0.75),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
