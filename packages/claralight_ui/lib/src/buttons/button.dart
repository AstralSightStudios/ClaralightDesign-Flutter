import 'package:flutter/widgets.dart';

import '../containers/toolbar_scope.dart';
import '../foundation/control_size.dart';
import '../foundation/shape.dart';
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

  /// Destructive action with the semantic danger color.
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

  /// Configured variant. When omitted, the button defaults to [CLButtonVariant.primary]
  /// outside a toolbar and [CLButtonVariant.ghost] inside one.
  final CLButtonVariant variant;
  final bool _usesDefaultVariant;

  /// Configured size, defaulting to large outside a toolbar.
  CLControlSize get size => _sizeOverride ?? CLControlSize.large;
  final CLControlSize? _sizeOverride;

  /// Optional fixed width. Null hugs the content.
  final double? width;

  /// Overrides the variant fill.
  final Color? tint;

  /// Overrides whether the button draws a hairline outline.
  ///
  /// Null outlines every variant except [CLButtonVariant.ghost].
  final bool? outlined;

  /// Overrides the theme outline color when the outline is visible.
  final Color? outlineColor;

  const CLButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    CLButtonVariant? variant,
    CLControlSize? size,
    this.width,
    this.tint,
    this.outlined,
    this.outlineColor,
  }) : variant = variant ?? CLButtonVariant.primary,
       _usesDefaultVariant = variant == null,
       _sizeOverride = size;

  @override
  State<CLButton> createState() => _CLButtonState();
}

class _CLButtonState extends State<CLButton> {
  bool _hovered = false;

  CLControlSize get _size =>
      widget._sizeOverride ??
      CLToolbarScope.maybeOf(context)?.size ??
      CLControlSize.large;

  double get _height => _size.controlHeight;

  double get _hPadding => switch (_size) {
    CLControlSize.small => 12,
    CLControlSize.medium => 16,
    CLControlSize.large => 20,
  };

  double get _iconSize => switch (_size) {
    CLControlSize.small => 15,
    CLControlSize.medium => 18,
    CLControlSize.large => 22,
  };

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final inToolbar = CLToolbarScope.maybeOf(context) != null;
    final effectiveVariant = widget._usesDefaultVariant && inToolbar
        ? CLButtonVariant.ghost
        : widget.variant;
    final outlined =
        widget.outlined ?? effectiveVariant != CLButtonVariant.ghost;
    final radius = BorderRadius.circular(theme.radii.capsule);
    final foreground = _foregroundColor(theme, effectiveVariant);
    final textStyle =
        (_size == CLControlSize.large
                ? theme.typography.title
                : theme.typography.label)
            .copyWith(color: foreground);

    final row = Row(
      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          _iconSlot(widget.leadingIcon!, foreground),
          SizedBox(width: _size == CLControlSize.small ? 6 : 8),
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
          SizedBox(width: _size == CLControlSize.small ? 6 : 8),
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
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: clSmoothDecoration(
                borderRadius: radius,
                side: outlined
                    ? BorderSide(
                        color: widget.outlineColor ?? theme.colors.outline,
                      )
                    : BorderSide.none,
              ),
              child: CLSurface(
                fill: _fillColor(
                  theme,
                  effectiveVariant,
                  pressedHover: _hovered && _enabled,
                ),
                frosted: effectiveVariant != CLButtonVariant.ghost,
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
      ),
    );
  }

  Widget _iconSlot(Widget icon, Color color) {
    return IconTheme.merge(
      data: IconThemeData(color: color, size: _iconSize),
      child: icon,
    );
  }

  Color _fillColor(
    CLThemeData theme,
    CLButtonVariant variant, {
    required bool pressedHover,
  }) {
    final colors = theme.colors;
    final tint = widget.tint;
    var fill = switch (variant) {
      CLButtonVariant.primary => tint ?? colors.accent,
      CLButtonVariant.secondary =>
        tint ?? (pressedHover ? colors.controlHighlight : colors.control),
      CLButtonVariant.ghost =>
        tint ??
            (pressedHover ? colors.controlHighlight : const Color(0x00000000)),
      CLButtonVariant.danger => tint ?? colors.danger,
    };
    if (pressedHover &&
        (variant == CLButtonVariant.primary ||
            variant == CLButtonVariant.danger)) {
      fill = Color.lerp(fill, const Color(0xFFFFFFFF), 0.08)!;
    }
    if (!_enabled) {
      // Disabled buttons drop their variant color entirely — a colored
      // button reads as tappable no matter how dim.
      fill = colors.control;
    }
    return fill;
  }

  Color _foregroundColor(CLThemeData theme, CLButtonVariant variant) {
    final colors = theme.colors;
    final color = switch (variant) {
      CLButtonVariant.primary => colors.onAccent,
      CLButtonVariant.secondary => colors.textPrimary,
      CLButtonVariant.ghost => colors.textPrimary,
      CLButtonVariant.danger => colors.onDanger,
    };
    return _enabled ? color : colors.textDisabled;
  }
}
