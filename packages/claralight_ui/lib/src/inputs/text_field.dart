import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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

  /// Whether to render the field with error-state colors.
  ///
  /// Numeric validation errors are combined with this external state.
  final bool error;

  final bool obscureText;
  final TextAlign textAlign;
  final CLControlSize size;

  /// The numeric increment used by the step buttons and arrow keys.
  ///
  /// A value of zero hides the step buttons. This only applies when
  /// [keyboardType] is numeric.
  final double step;

  /// Optional inclusive bounds for numeric input.
  final double? min;
  final double? max;

  /// Formats values produced by stepping. The result must remain parseable as
  /// a [double] so it can be edited and stepped again.
  final String Function(double value)? format;

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
    this.error = false,
    this.obscureText = false,
    this.textAlign = TextAlign.start,
    this.size = CLControlSize.large,
    this.step = 0,
    this.min,
    this.max,
    this.format,
    this.mono = false,
    this.borderRadius,
    this.width,
  }) : assert(step >= 0 && step < double.infinity),
       assert(
         min == null ||
             (min > double.negativeInfinity && min < double.infinity),
       ),
       assert(
         max == null ||
             (max > double.negativeInfinity && max < double.infinity),
       ),
       assert(min == null || max == null || min <= max);

  @override
  State<CLTextField> createState() => _CLTextFieldState();
}

class _CLTextFieldState extends State<CLTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _showValidationError = false;

  @override
  void initState() {
    super.initState();
    _adoptController();
    _adoptFocusNode();
  }

  @override
  void didUpdateWidget(CLTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      if (_ownsController) _controller.dispose();
      _adoptController();
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _adoptFocusNode();
    }
  }

  void _adoptController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _adoptFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isNumeric) {
      _showValidationError = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };

  bool get _isNumeric =>
      widget.keyboardType?.index == TextInputType.number.index;

  bool get _showsStepper => _isNumeric && widget.step > 0;

  double? get _number {
    final value = double.tryParse(_controller.text.trim());
    return value != null && value.isFinite ? value : null;
  }

  bool get _isValidNumber {
    final value = _number;
    if (value == null) return false;
    if (widget.min case final min? when value < min) return false;
    if (widget.max case final max? when value > max) return false;
    return true;
  }

  bool get _showsError =>
      widget.enabled &&
      (widget.error || (_isNumeric && _showValidationError && !_isValidNumber));

  bool _canStep(double direction) {
    if (!widget.enabled || !_showsStepper) return false;
    final value = _number;
    if (value == null) return false;
    final min = widget.min;
    final max = widget.max;
    if (direction > 0 && max != null && value >= max) return false;
    if (direction < 0 && min != null && value <= min) return false;
    return true;
  }

  void _bump(double direction) {
    if (!_canStep(direction)) return;
    final current = _number!;
    var next = current + direction * widget.step;
    if (!next.isFinite) return;
    if (widget.min case final min? when next < min) next = min;
    if (widget.max case final max? when next > max) next = max;

    final text = widget.format?.call(next) ?? _defaultNumberFormat(next);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
  }

  String _defaultNumberFormat(double value) {
    final rounded = double.parse(value.toStringAsPrecision(15));
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
  }

  void _handleSubmitted(String value) {
    if (_isNumeric && !_isValidNumber) {
      setState(() => _showValidationError = true);
      _focusNode.requestFocus();
      return;
    }
    widget.onSubmitted?.call(value);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showsStepper || !widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _bump(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _bump(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final focused = _focusNode.hasFocus;
    final useMono = widget.mono || _showsStepper;

    final textStyle =
        (useMono
                ? theme.typography.monoStrong
                : widget.size == CLControlSize.large
                ? theme.typography.body
                : theme.typography.callout)
            .copyWith(
              color: !widget.enabled
                  ? colors.textDisabled
                  : _showsError
                  ? colors.danger
                  : colors.textPrimary,
            );

    final field = CupertinoTextField(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder,
      placeholderStyle: textStyle.copyWith(color: colors.textHint),
      style: textStyle,
      cursorColor: _showsError ? colors.danger : colors.accent,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      textAlign: widget.textAlign,
      onChanged: widget.onChanged,
      onSubmitted: _handleSubmitted,
      decoration: null,
      padding: EdgeInsets.zero,
      maxLines: 1,
    );

    final horizontalPad = widget.size == CLControlSize.small ? 10.0 : 12.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focusNode.requestFocus : null,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleKeyEvent,
        child: SizedBox(
          width: widget.width,
          height: _height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: clSmoothDecoration(
              color: widget.enabled
                  ? colors.control
                  : colors.control.withValues(alpha: colors.control.a * 0.5),
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? theme.radii.control,
              ),
              // Borderless at rest; focused fields use the accent or error ring.
              side: BorderSide(
                color: focused
                    ? (_showsError ? colors.danger : colors.accent)
                    : const Color(0x00000000),
                width: focused ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.only(
              left: horizontalPad,
              right: _showsStepper ? 6 : horizontalPad,
            ),
            child: Row(
              children: [
                if (_showsStepper) ...[
                  if (widget.prefix != null) ...[
                    _stepperSlot(widget.prefix!, theme, unit: false),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: IntrinsicWidth(child: field),
                          ),
                          if (widget.suffix != null)
                            _stepperSlot(widget.suffix!, theme, unit: true),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ChevronButton(
                        key: const Key('cl-text-field-step-up'),
                        up: true,
                        enabled: _canStep(1),
                        onTap: () {
                          _focusNode.requestFocus();
                          _bump(1);
                        },
                      ),
                      _ChevronButton(
                        key: const Key('cl-text-field-step-down'),
                        up: false,
                        enabled: _canStep(-1),
                        onTap: () {
                          _focusNode.requestFocus();
                          _bump(-1);
                        },
                      ),
                    ],
                  ),
                ] else ...[
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
              ],
            ),
          ),
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

  Widget _stepperSlot(Widget child, CLThemeData theme, {required bool unit}) {
    final color = widget.enabled
        ? theme.colors.textTertiary
        : theme.colors.textDisabled;
    final style = unit
        ? theme.typography.mono
        : theme.typography.callout.withCLWeight(FontWeight.w400);

    return IconTheme.merge(
      data: IconThemeData(
        color: color,
        size: widget.size == CLControlSize.small ? 14 : 18,
      ),
      child: DefaultTextStyle.merge(
        style: style.copyWith(color: color),
        child: child,
      ),
    );
  }
}

class _ChevronButton extends StatefulWidget {
  final bool up;
  final bool enabled;
  final VoidCallback onTap;

  const _ChevronButton({
    super.key,
    required this.up,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ChevronButton> createState() => _ChevronButtonState();
}

class _ChevronButtonState extends State<_ChevronButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = CLTheme.of(context).colors;
    final color = widget.enabled
        ? (_hovered ? colors.textPrimary : colors.textSecondary)
        : colors.textDisabled;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: 18,
          height: 10,
          child: Center(
            child: CustomPaint(
              size: const Size(8, 4.5),
              painter: _StepChevronPainter(color: color, up: widget.up),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepChevronPainter extends CustomPainter {
  final Color color;
  final bool up;

  const _StepChevronPainter({required this.color, required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StepChevronPainter oldDelegate) =>
      color != oldDelegate.color || up != oldDelegate.up;
}
