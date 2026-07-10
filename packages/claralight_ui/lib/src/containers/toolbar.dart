import 'package:flutter/widgets.dart';

import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// A Claralight toolbar capsule — the floating tool clusters at the top of
/// the desktop mockup.
///
/// Groups its children inside a single control-fill capsule, with optional
/// hairline dividers between them.
class CLToolbar extends StatelessWidget {
  final List<Widget> children;

  /// Whether hairline dividers separate the children.
  final bool dividers;

  /// Height of the capsule.
  final double height;

  /// Horizontal padding inside the capsule.
  final double padding;

  /// Gap between children.
  final double spacing;

  const CLToolbar({
    super.key,
    required this.children,
    this.dividers = false,
    this.height = 44,
    this.padding = 6,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);

    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        if (dividers) {
          items.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing + 2),
              child: SizedBox(
                width: 1,
                height: height * 0.5,
                child: ColoredBox(color: theme.colors.separator),
              ),
            ),
          );
        } else {
          items.add(SizedBox(width: spacing));
        }
      }
      items.add(children[i]);
    }

    return SizedBox(
      height: height,
      child: CLSurface(
        level: CLSurfaceLevel.control,
        borderRadius: BorderRadius.circular(height / 2),
        outlined: true,
        shadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}
