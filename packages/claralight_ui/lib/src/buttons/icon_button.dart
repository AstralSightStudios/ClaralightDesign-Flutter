import 'package:flutter/material.dart';

import 'package:claralight_ui/src/surfaces/glass.dart';
import 'package:claralight_ui/src/surfaces/interactive_glass.dart';

class CLIconButton extends StatelessWidget {
  static const double defaultSize = 48;
  static const double iconSize = 24;

  final IconData icon;
  final VoidCallback onPressed;

  /// Uses the liquid press and drag highlight when true.
  ///
  /// When false, the button keeps the same glass surface and uses Material's
  /// regular tap indication instead.
  final bool isInteractive;

  /// Optional hue/tint color for the glass surface.
  ///
  /// Mirrors the Android LiquidButton tint pass with a 75% surface tint.
  final Color? tint;

  /// Optional solid surface color drawn above [tint].
  final Color? surfaceColor;

  const CLIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isInteractive = true,
    this.tint,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(defaultSize / 2);
    final content = Icon(icon, color: const Color(0xFFEDEDED), size: iconSize);

    return Semantics(
      button: true,
      child: isInteractive
          ? InteractiveGlass(
              onTap: onPressed,
              size: defaultSize,
              borderRadius: radius,
              backgroundColor: _surfaceTint,
              child: content,
            )
          : SizedBox(
              width: defaultSize,
              height: defaultSize,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Glass(
                    blur: 2,
                    borderRadius: radius,
                    backgroundColor: _surfaceTint,
                    child: Center(child: content),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: onPressed, borderRadius: radius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Color get _surfaceTint =>
      surfaceColor ?? tint?.withValues(alpha: 0.75) ?? Colors.transparent;
}
