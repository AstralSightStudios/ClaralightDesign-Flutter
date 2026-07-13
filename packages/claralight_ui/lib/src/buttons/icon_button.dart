import 'package:flutter/widgets.dart';

import '../containers/toolbar_scope.dart';
import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../surfaces/pressable.dart';
import '../surfaces/surface.dart';
import '../theme/theme.dart';

/// Shape of a [CLIconButton].
enum CLIconButtonShape {
  /// Full circle — the floating buttons of the mobile mockup.
  circle,

  /// Rounded rectangle — the inspector grid buttons of the desktop mockup.
  rounded,
}

/// Visual treatment of a [CLIconButton].
enum CLIconButtonVariant {
  /// Accent-filled primary action.
  primary,

  /// Neutral control fill, used by toolbars and inspectors.
  secondary,

  /// Transparent until hovered, for quiet contextual actions.
  ghost,

  /// Destructive action with the semantic danger color.
  danger,
}

/// A Claralight icon button.
///
/// A circle or rounded rectangle with a semantic, neutral, or ghost treatment
/// and a [selected] state.
class CLIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  /// Configured size, defaulting to large outside a toolbar.
  CLControlSize get size => _sizeOverride ?? CLControlSize.large;
  final CLControlSize? _sizeOverride;

  final CLIconButtonShape shape;

  /// Configured variant. When omitted, the button defaults to
  /// [CLIconButtonVariant.secondary] outside a toolbar and
  /// [CLIconButtonVariant.ghost] inside one.
  final CLIconButtonVariant variant;
  final bool _usesDefaultVariant;

  /// Selected buttons use a raised control fill. Inside a [CLToolbar], the
  /// selection stays neutral so it does not compete with primary actions.
  final bool selected;

  /// Overrides the resting fill.
  final Color? fill;

  /// Overrides the selected fill.
  final Color? selectedFill;

  /// Overrides the icon color.
  final Color? iconColor;

  /// Overrides whether the button draws a hairline outline.
  ///
  /// Null outlines every variant except [CLIconButtonVariant.ghost].
  final bool? outlined;

  /// Overrides the theme outline color when the outline is visible.
  final Color? outlineColor;

  /// Accessibility label.
  final String? semanticLabel;

  const CLIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    CLControlSize? size,
    this.shape = CLIconButtonShape.circle,
    CLIconButtonVariant? variant,
    this.selected = false,
    this.fill,
    this.selectedFill,
    this.iconColor,
    this.outlined,
    this.outlineColor,
    this.semanticLabel,
  }) : variant = variant ?? CLIconButtonVariant.secondary,
       _usesDefaultVariant = variant == null,
       _sizeOverride = size;

  @override
  State<CLIconButton> createState() => _CLIconButtonState();
}

class _CLIconButtonState extends State<CLIconButton> {
  bool _hovered = false;

  double _iconSize(CLControlSize size) => switch (size) {
    CLControlSize.small => 16,
    CLControlSize.medium => 19,
    CLControlSize.large => 22,
  };

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final toolbar = CLToolbarScope.maybeOf(context);
    final size = widget._sizeOverride ?? toolbar?.size ?? CLControlSize.large;
    final extent = size.controlHeight;
    final radius = BorderRadius.circular(
      widget.shape == CLIconButtonShape.circle
          ? extent / 2
          : theme.radii.control,
    );

    final isHovered = _hovered && _enabled;
    final inToolbar = toolbar != null;
    final effectiveVariant = widget._usesDefaultVariant && inToolbar
        ? CLIconButtonVariant.ghost
        : widget.variant;
    final isSemanticVariant =
        effectiveVariant == CLIconButtonVariant.primary ||
        effectiveVariant == CLIconButtonVariant.danger;
    final outlined =
        widget.outlined ?? effectiveVariant != CLIconButtonVariant.ghost;
    var fill = widget.selected
        ? (widget.selectedFill ??
              (isSemanticVariant
                  ? _fillColor(theme, effectiveVariant, isHovered: false)
                  : inToolbar
                  ? isHovered
                        ? theme.colors.controlHighlight
                        : theme.colors.control
                  : theme.colors.controlHighlight))
        : (widget.fill ??
              _fillColor(theme, effectiveVariant, isHovered: isHovered));
    if (!_enabled) {
      fill = isSemanticVariant && widget.fill == null
          ? theme.colors.control
          : fill.withValues(alpha: fill.a * 0.45);
    }

    final iconColor = !_enabled
        ? theme.colors.textDisabled
        : widget.iconColor ??
              (isSemanticVariant
                  ? _foregroundColor(theme, effectiveVariant)
                  : widget.selected && !inToolbar
                  ? theme.colors.textPrimary
                  : theme.colors.textSecondary);

    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: CLPressable(
          onTap: widget.onPressed,
          borderRadius: radius,
          pressedScale: 1 + 4 / extent,
          child: SizedBox(
            width: extent,
            height: extent,
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
                fill: fill,
                borderRadius: radius,
                frosted:
                    effectiveVariant != CLIconButtonVariant.ghost && fill.a > 0,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: _iconSize(size),
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _fillColor(
    CLThemeData theme,
    CLIconButtonVariant variant, {
    required bool isHovered,
  }) {
    final colors = theme.colors;
    return switch (variant) {
      CLIconButtonVariant.primary =>
        isHovered
            ? Color.lerp(colors.accent, const Color(0xFFFFFFFF), 0.08)!
            : colors.accent,
      CLIconButtonVariant.secondary =>
        isHovered ? colors.controlHighlight : colors.control,
      CLIconButtonVariant.ghost =>
        isHovered ? colors.controlHighlight : const Color(0x00000000),
      CLIconButtonVariant.danger =>
        isHovered
            ? Color.lerp(colors.danger, const Color(0xFFFFFFFF), 0.08)!
            : colors.danger,
    };
  }

  Color _foregroundColor(CLThemeData theme, CLIconButtonVariant variant) {
    return switch (variant) {
      CLIconButtonVariant.primary => theme.colors.onAccent,
      CLIconButtonVariant.danger => theme.colors.onDanger,
      CLIconButtonVariant.secondary ||
      CLIconButtonVariant.ghost => theme.colors.textSecondary,
    };
  }
}
