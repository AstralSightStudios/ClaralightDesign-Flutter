import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A Claralight side panel — the left column of the desktop mockup.
///
/// A flat [CLSurface] at panel level with a hairline outline.
class CLSideBar extends StatelessWidget {
  final Widget child;

  /// Fixed width; null sizes to the parent.
  final double? width;

  /// Padding inside the panel.
  final EdgeInsetsGeometry padding;

  const CLSideBar({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return SizedBox(
      width: width,
      child: CLSurface(
        level: CLSurfaceLevel.panel,
        borderRadius: BorderRadius.circular(theme.radii.panel),
        outlined: true,
        outlineColor: theme.colors.outlineStrong,
        padding: padding,
        child: child,
      ),
    );
  }
}
