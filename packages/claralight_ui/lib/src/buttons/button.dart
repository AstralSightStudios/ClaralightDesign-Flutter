import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:claralight_ui/src/surfaces/interactive_glass.dart';

/// Visual variants from the Figma button component.
enum CLButtonVariant { primary, neutral, danger }

class CLButton extends StatelessWidget {
  static const double defaultHeight = 50;
  static const double defaultWidth = 354;
  static const double minWidth = 64;
  static const double horizontalInset = 16;
  static const double iconSize = 24;

  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final CLButtonVariant variant;

  /// Button width. Pass any finite width, or null to use the Figma width.
  ///
  /// The Figma minimum width is still enforced by [minWidth].
  final double? width;

  const CLButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = CLButtonVariant.primary,
    this.width = defaultWidth,
  }) : assert(width == null || (width > 0 && width < double.infinity));

  @override
  Widget build(BuildContext context) {
    final surfaceWidth = math.max(width ?? defaultWidth, minWidth);
    final radius = BorderRadius.circular(defaultHeight / 2);
    final content = _ButtonContent(
      label: label,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      foregroundColor: _foregroundColor,
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InteractiveGlass(
        onTap: onPressed,
        width: surfaceWidth,
        height: defaultHeight,
        borderRadius: radius,
        pressedScale: 1.1,
        blur: 3,
        backgroundColor: _backgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        child: SizedBox.expand(child: content),
      ),
    );
  }

  Color get _foregroundColor => const Color(0xFFF7F7F2);

  Color get _backgroundColor => switch (variant) {
    CLButtonVariant.primary => const Color(0xFF2482C5),
    CLButtonVariant.neutral => const Color(0xFF575757),
    CLButtonVariant.danger => const Color(0xFFC93442),
  };
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final Color foregroundColor;

  const _ButtonContent({
    required this.label,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.foregroundColor,
  });

  bool get _hasAnyIcon => leadingIcon != null || trailingIcon != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CLButton.horizontalInset),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: _hasAnyIcon
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          if (_hasAnyIcon)
            _IconSlot(icon: leadingIcon, foregroundColor: foregroundColor),
          _Label(label: label, foregroundColor: foregroundColor),
          if (_hasAnyIcon)
            _IconSlot(icon: trailingIcon, foregroundColor: foregroundColor),
        ],
      ),
    );
  }
}

class _IconSlot extends StatelessWidget {
  final Widget? icon;
  final Color foregroundColor;

  const _IconSlot({required this.icon, required this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CLButton.iconSize,
      height: CLButton.iconSize,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(color: foregroundColor, size: CLButton.iconSize),
          child: icon ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  final Color foregroundColor;

  const _Label({required this.label, required this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(
        color: foregroundColor,
        fontFamily: 'MiSans VF',
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 22 / 17,
        letterSpacing: -0.43,
        shadows: const [Shadow(color: Color(0x78000000), blurRadius: 14.2)],
      ),
      child: Text(label, softWrap: false),
    );
  }
}
