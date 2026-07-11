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
  ///
  /// Optically compensated: the capsule's curved ends bow away from the
  /// content, so an end inset equal to the vertical gap (4 for a 36px
  /// control in the 44px capsule) still *reads* wider. One point tighter
  /// makes all four sides look even.
  final double padding;

  /// Gap between children.
  final double spacing;

  /// Overrides the control-level fill — the dark floating pills over the
  /// editor canvas use `Colors/Gray Alpha/11` instead.
  final Color? fill;

  /// Whether the capsule draws its hairline outline. Floating pills over
  /// imagery drop it and rely on their shadow.
  final bool outlined;

  const CLToolbar({
    super.key,
    required this.children,
    this.dividers = false,
    this.height = 44,
    this.padding = 3,
    this.spacing = 2,
    this.fill,
    this.outlined = true,
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
        fill: fill,
        borderRadius: BorderRadius.circular(height / 2),
        outlined: outlined,
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
