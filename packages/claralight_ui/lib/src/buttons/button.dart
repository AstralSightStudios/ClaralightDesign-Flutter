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

  /// Dark glass action floating over arbitrary canvas content.
  floating,

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
  /// Null outlines every variant except [CLButtonVariant.ghost] and
  /// [CLButtonVariant.floating].
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

  // Figma's touch CTAs are intentionally taller than the shared large
  // control density: 50px with a 24px icon slot.
  double get _height => switch (_size) {
    CLControlSize.small || CLControlSize.medium => _size.controlHeight,
    CLControlSize.large => 50,
  };

  double get _hPadding => switch (_size) {
    CLControlSize.small => 12,
    CLControlSize.medium || CLControlSize.large => 16,
  };

  double get _iconSize => switch (_size) {
    CLControlSize.small => 15,
    CLControlSize.medium => 18,
    CLControlSize.large => 24,
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
        widget.outlined ??
        (effectiveVariant != CLButtonVariant.ghost &&
            effectiveVariant != CLButtonVariant.floating);
    final radius = BorderRadius.circular(theme.radii.capsule);
    final foreground = _foregroundColor(theme, effectiveVariant);
    final textStyle =
        (_size == CLControlSize.large
                ? theme.typography.title
                      .withCLWeight(FontWeight.w500)
                      .copyWith(
                        fontSize: 17,
                        height: 22 / 17,
                        letterSpacing: -0.43,
                      )
                : theme.typography.label)
            .copyWith(color: foreground);
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
                frostSigma: effectiveVariant == CLButtonVariant.floating
                    ? 10
                    : 47.9,
                shadow: effectiveVariant == CLButtonVariant.ghost
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x33000000),
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                borderRadius: radius,
                padding: EdgeInsets.symmetric(horizontal: _hPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // `Expanded`, as used by ExportPage, gives this button a
                    // tight width without setting `widget.width`. Use the real
                    // constraint so either route keeps the label centered.
                    final fillsAvailableWidth =
                        widget.width != null || constraints.hasTightWidth;
                    return Align(
                      widthFactor: fillsAvailableWidth ? null : 1,
                      child: fillsAvailableWidth
                          ? _fullWidthContent(textStyle, foreground)
                          : _huggingContent(textStyle, foreground),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact content used by buttons that do not have a prescribed width.
  Widget _huggingContent(TextStyle textStyle, Color foreground) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
  }

  /// Fixed-width CTAs reserve equal edge slots. This keeps the label on the
  /// visual centerline whether the action has a back, forward, or no icon.
  Widget _fullWidthContent(TextStyle textStyle, Color foreground) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Text(
            widget.label,
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ),
        if (widget.leadingIcon != null)
          PositionedDirectional(
            start: 0,
            top: (_height - _iconSize) / 2,
            child: _iconSlot(widget.leadingIcon!, foreground),
          ),
        if (widget.trailingIcon != null)
          PositionedDirectional(
            end: 0,
            top: (_height - _iconSize) / 2,
            child: _iconSlot(widget.trailingIcon!, foreground),
          ),
      ],
    );
  }

  Widget _iconSlot(Widget icon, Color color) {
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: IconTheme.merge(
        data: IconThemeData(color: color, size: _iconSize),
        child: icon,
      ),
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
      CLButtonVariant.floating => tint ?? colors.floatingControl,
      CLButtonVariant.danger => tint ?? colors.danger,
    };
    if (pressedHover &&
        (variant == CLButtonVariant.primary ||
            variant == CLButtonVariant.floating ||
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
      CLButtonVariant.floating => colors.onFloatingControl,
      CLButtonVariant.danger => colors.onDanger,
    };
    return _enabled ? color : colors.textDisabled;
  }
}
