import 'package:flutter/widgets.dart';

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
  /// Neutral control fill, used by toolbars and inspectors.
  secondary,

  /// Transparent until hovered, for quiet contextual actions.
  ghost,
}

/// A Claralight icon button.
///
/// A circle or rounded rectangle with a secondary or ghost treatment and a
/// [selected] accent state.
class CLIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final CLControlSize size;
  final CLIconButtonShape shape;
  final CLIconButtonVariant variant;

  /// Selected buttons use the selection fill (or [selectedFill]).
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
    this.size = CLControlSize.large,
    this.shape = CLIconButtonShape.circle,
    this.variant = CLIconButtonVariant.secondary,
    this.selected = false,
    this.fill,
    this.selectedFill,
    this.iconColor,
    this.semanticLabel,
  });

  @override
  State<CLIconButton> createState() => _CLIconButtonState();
}

class _CLIconButtonState extends State<CLIconButton> {
  bool _hovered = false;

  double get _extent => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };

  double get _iconSize => switch (widget.size) {
    CLControlSize.small => 16,
    CLControlSize.medium => 19,
    CLControlSize.large => 22,
  };

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius = BorderRadius.circular(
      widget.shape == CLIconButtonShape.circle
          ? _extent / 2
          : theme.radii.control,
    );

    final isHovered = _hovered && _enabled;
    var fill = widget.selected
        ? (widget.selectedFill ?? theme.colors.controlHighlight)
        : (widget.fill ?? _fillColor(theme, isHovered: isHovered));
    if (!_enabled) fill = fill.withValues(alpha: fill.a * 0.45);

    final iconColor = !_enabled
        ? theme.colors.textDisabled
        : widget.iconColor ??
            (widget.selected
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
          pressedScale: 1 + 4 / _extent,
          child: SizedBox(
            width: _extent,
            height: _extent,
            child: CLSurface(
              fill: fill,
              borderRadius: radius,
              child: Center(
                child: Icon(widget.icon, size: _iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _fillColor(CLThemeData theme, {required bool isHovered}) {
    if (isHovered) return theme.colors.controlHighlight;

    return switch (widget.variant) {
      CLIconButtonVariant.secondary => theme.colors.control,
      CLIconButtonVariant.ghost => const Color(0x00000000),
    };
  }
}
