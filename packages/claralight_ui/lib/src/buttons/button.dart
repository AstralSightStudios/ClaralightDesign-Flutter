import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';
import '../surfaces/pressable.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// Claralight button variants.
enum CLButtonVariant {
  /// Accent-filled call to action (the blue upload button in the mockups).
  primary,

  /// Neutral control-fill button (toolbar and inspector buttons).
  secondary,

  /// No fill until hovered; for rows of quiet actions.
  ghost,

  /// Destructive action.
  danger,
}

/// A Claralight capsule button.
///
/// Opaque layered fill per variant; press interaction is the springy
/// Claralight scale + jelly drag.
class CLButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final CLButtonVariant variant;
  final CLControlSize size;

  /// Optional fixed width. Null hugs the content.
  final double? width;

  /// Overrides the variant fill.
  final Color? tint;

  const CLButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = CLButtonVariant.primary,
    this.size = CLControlSize.large,
    this.width,
    this.tint,
  });

  @override
  State<CLButton> createState() => _CLButtonState();
}

class _CLButtonState extends State<CLButton> {
  bool _hovered = false;

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 48,
  };

  double get _hPadding => switch (widget.size) {
    CLControlSize.small => 12,
    CLControlSize.medium => 16,
    CLControlSize.large => 20,
  };

  double get _iconSize => switch (widget.size) {
    CLControlSize.small => 15,
    CLControlSize.medium => 18,
    CLControlSize.large => 22,
  };

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius = BorderRadius.circular(theme.radii.capsule);
    final foreground = _foregroundColor(theme);
    final textStyle = (widget.size == CLControlSize.large
            ? theme.typography.title
            : theme.typography.label)
        .copyWith(color: foreground);

    final row = Row(
      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          _iconSlot(widget.leadingIcon!, foreground),
          SizedBox(width: widget.size == CLControlSize.small ? 6 : 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: textStyle,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          SizedBox(width: widget.size == CLControlSize.small ? 6 : 8),
          _iconSlot(widget.trailingIcon!, foreground),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: CLPressable(
          onTap: widget.onPressed,
          borderRadius: radius,
          pressedScale: 1 + 4 / _height / 2,
          child: SizedBox(
            width: widget.width,
            height: _height,
            child: CLSurface(
              fill: _fillColor(theme, pressedHover: _hovered && _enabled),
              frosted: widget.variant != CLButtonVariant.ghost,
              borderRadius: radius,
              padding: EdgeInsets.symmetric(horizontal: _hPadding),
              // widthFactor 1 hugs the content when no width is given;
              // with a fixed width the Align expands and centers instead.
              child: Align(
                widthFactor: widget.width == null ? 1 : null,
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconSlot(Widget icon, Color color) {
    return IconTheme.merge(
      data: IconThemeData(color: color, size: _iconSize),
      child: icon,
    );
  }

  Color _fillColor(CLThemeData theme, {required bool pressedHover}) {
    final colors = theme.colors;
    final tint = widget.tint;
    var fill = switch (widget.variant) {
      CLButtonVariant.primary => tint ?? colors.accent,
      CLButtonVariant.secondary =>
        tint ?? (pressedHover ? colors.controlHighlight : colors.control),
      CLButtonVariant.ghost =>
        tint ?? (pressedHover ? colors.controlHighlight : const Color(0x00000000)),
      CLButtonVariant.danger => tint ?? colors.danger,
    };
    if (pressedHover &&
        (widget.variant == CLButtonVariant.primary ||
            widget.variant == CLButtonVariant.danger)) {
      fill = Color.lerp(fill, const Color(0xFFFFFFFF), 0.08)!;
    }
    if (!_enabled) {
      // Disabled buttons drop their variant color entirely — a colored
      // button reads as tappable no matter how dim.
      fill = colors.control;
    }
    return fill;
  }

  Color _foregroundColor(CLThemeData theme) {
    final colors = theme.colors;
    final color = switch (widget.variant) {
      CLButtonVariant.primary => colors.onAccent,
      CLButtonVariant.secondary => colors.textPrimary,
      CLButtonVariant.ghost => colors.textPrimary,
      CLButtonVariant.danger => colors.onDanger,
    };
    return _enabled ? color : colors.textDisabled;
  }
}
