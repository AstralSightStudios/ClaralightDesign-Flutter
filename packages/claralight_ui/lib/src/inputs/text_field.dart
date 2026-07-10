import 'package:flutter/cupertino.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../theme/theme.dart';

/// A Claralight text field — the inspector inputs of the desktop mockup
/// ("X 12px", "W 78") and the touch fields of the mobile mockup.
///
/// A flat control-fill rounded rectangle with an optional [prefix] label
/// (dimmed, e.g. the axis letter), an optional [suffix] (unit or actions)
/// and an animated accent focus ring.
class CLTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;

  /// Leading widget or short label, rendered dimmed (e.g. "X", an icon).
  final Widget? prefix;

  /// Trailing widget (e.g. a unit label or clear button).
  final Widget? suffix;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;
  final TextAlign textAlign;
  final CLControlSize size;

  /// Renders the value in the monospace family — for numeric fields like
  /// the design's "X 12px" inspector inputs.
  final bool mono;

  /// Corner radius override; null uses the theme's control radius. Use a
  /// larger value inside large-radius containers so the corners stay
  /// optically concentric.
  final double? borderRadius;

  /// Fixed width; null fills the parent.
  final double? width;

  const CLTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.enabled = true,
    this.obscureText = false,
    this.textAlign = TextAlign.start,
    this.size = CLControlSize.large,
    this.mono = false,
    this.borderRadius,
    this.width,
  });

  @override
  State<CLTextField> createState() => _CLTextFieldState();
}

class _CLTextFieldState extends State<CLTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _adoptFocusNode();
  }

  @override
  void didUpdateWidget(CLTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsFocusNode) _focusNode.dispose();
      _adoptFocusNode();
    }
  }

  void _adoptFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final focused = _focusNode.hasFocus;

    final textStyle = (widget.mono
            ? theme.typography.monoStrong
            : widget.size == CLControlSize.large
                ? theme.typography.body
                : theme.typography.callout)
        .copyWith(
      color: widget.enabled ? colors.textPrimary : colors.textDisabled,
    );

    final field = CupertinoTextField(
      controller: widget.controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder,
      placeholderStyle: textStyle.copyWith(color: colors.textHint),
      style: textStyle,
      cursorColor: colors.accent,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      textAlign: widget.textAlign,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: null,
      padding: EdgeInsets.zero,
      maxLines: 1,
    );

    final horizontalPad = widget.size == CLControlSize.small ? 10.0 : 12.0;

    return SizedBox(
      width: widget.width,
      height: _height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: clSmoothDecoration(
          color: widget.enabled
              ? colors.control
              : colors.control.withValues(alpha: colors.control.a * 0.5),
          borderRadius:
              BorderRadius.circular(widget.borderRadius ?? theme.radii.control),
          // Borderless at rest, per the design; the accent ring appears
          // only on focus.
          side: BorderSide(
            color: focused ? colors.accent : const Color(0x00000000),
            width: focused ? 1.5 : 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
        child: Row(
          children: [
            if (widget.prefix != null) ...[
              _slot(widget.prefix!, theme),
              SizedBox(width: widget.size == CLControlSize.small ? 6 : 8),
            ],
            Expanded(child: Center(child: field)),
            if (widget.suffix != null) ...[
              SizedBox(width: widget.size == CLControlSize.small ? 6 : 8),
              _slot(widget.suffix!, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slot(Widget child, CLThemeData theme) {
    return IconTheme.merge(
      data: IconThemeData(
        color: theme.colors.textTertiary,
        size: widget.size == CLControlSize.small ? 14 : 18,
      ),
      child: DefaultTextStyle.merge(
        style: (widget.mono ? theme.typography.mono : theme.typography.callout)
            .withCLWeight(FontWeight.w400)
            .copyWith(color: theme.colors.textTertiary),
        child: child,
      ),
    );
  }
}
