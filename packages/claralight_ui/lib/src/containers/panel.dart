import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A Claralight panel — the inspector panes of the desktop mockup.
///
/// A large-radius flat surface one step above the window background, with a
/// hairline outline.
class CLPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  /// Optional shadow, e.g. for floating panels.
  final List<BoxShadow>? shadow;

  const CLPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: CLSurface(
        level: CLSurfaceLevel.panel,
        borderRadius: BorderRadius.circular(theme.radii.panel),
        outlined: true,
        outlineColor: theme.colors.outlineStrong,
        shadow: shadow,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// A dimmed section header inside panels and sheets ("表盘样式", "对齐").
class CLSectionHeader extends StatelessWidget {
  final String label;

  /// Optional trailing widget, e.g. a small "+" button.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  const CLSectionHeader(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 8, bottom: 4),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.typography.label
                  .copyWith(color: theme.colors.textHint),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
