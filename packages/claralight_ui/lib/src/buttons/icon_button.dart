import 'package:flutter/widgets.dart';

import '../containers/toolbar_scope.dart';
import '../foundation/control_size.dart';
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
  final CLIconButtonVariant variant;

  /// Selected buttons use a raised control fill. Inside a [CLToolbar], the
  /// selection stays neutral so it does not compete with primary actions.
  final bool selected;

  /// Overrides the resting fill.
  final Color? fill;

  /// Overrides the selected fill.
  final Color? selectedFill;

  /// Overrides the icon color.
  final Color? iconColor;

  /// Accessibility label.
  final String? semanticLabel;

  const CLIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    CLControlSize? size,
    this.shape = CLIconButtonShape.circle,
    this.variant = CLIconButtonVariant.secondary,
    this.selected = false,
    this.fill,
    this.selectedFill,
    this.iconColor,
    this.semanticLabel,
  }) : _sizeOverride = size;

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
    final isSemanticVariant =
        widget.variant == CLIconButtonVariant.primary ||
        widget.variant == CLIconButtonVariant.danger;
    final quietInToolbar =
        inToolbar && widget.fill == null && !isSemanticVariant;
    var fill = widget.selected
        ? (widget.selectedFill ??
              (isSemanticVariant
                  ? _fillColor(theme, isHovered: false)
                  : inToolbar
                  ? isHovered
                        ? theme.colors.controlHighlight
                        : theme.colors.control
                  : theme.colors.controlHighlight))
        : (widget.fill ??
              (quietInToolbar
                  ? isHovered
                        ? theme.colors.controlHighlight
                        : const Color(0x00000000)
                  : _fillColor(theme, isHovered: isHovered)));
    if (!_enabled) {
      fill = isSemanticVariant && widget.fill == null
          ? theme.colors.control
          : fill.withValues(alpha: fill.a * 0.45);
    }

    final iconColor = !_enabled
        ? theme.colors.textDisabled
        : widget.iconColor ??
              (isSemanticVariant
                  ? _foregroundColor(theme)
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
            child: CLSurface(
              fill: fill,
              borderRadius: radius,
              frosted:
                  !quietInToolbar &&
                  widget.variant != CLIconButtonVariant.ghost &&
                  fill.a > 0,
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
    );
  }

  Color _fillColor(CLThemeData theme, {required bool isHovered}) {
    final colors = theme.colors;
    return switch (widget.variant) {
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

  Color _foregroundColor(CLThemeData theme) {
    return switch (widget.variant) {
      CLIconButtonVariant.primary => theme.colors.onAccent,
      CLIconButtonVariant.danger => theme.colors.onDanger,
      CLIconButtonVariant.secondary ||
      CLIconButtonVariant.ghost => theme.colors.textSecondary,
    };
  }
}
