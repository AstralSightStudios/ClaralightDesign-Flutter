import 'dart:async';
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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

  /// The numeric increment used by buttons, dragging, scrolling, and keys.
  ///
  /// A value of zero disables numeric adjustment and hides the step buttons.
  /// This only applies when [keyboardType] is numeric.
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

  double get _height => widget.size.controlHeight;

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

  String? _semanticSteppedValue(double direction) {
    if (!_canStep(direction)) return null;
    final stepped = _number! + direction * widget.step;
    if (!stepped.isFinite) return null;
    final next = _clampNumber(stepped);
    return widget.format?.call(next) ?? _defaultNumberFormat(next);
  }

  bool _bump(double direction) => _bumpSteps(direction > 0 ? 1 : -1);

  bool _bumpSteps(int steps) {
    if (steps == 0) return false;
    final direction = steps.sign.toDouble();
    if (!_canStep(direction)) return false;

    final current = _number!;
    var next = current + direction * widget.step;
    if (!next.isFinite) return false;
    next = _clampNumber(next);

    final remaining = steps.abs() - 1;
    if (remaining > 0) {
      next += direction * widget.step * remaining;
      if (!next.isFinite) return false;
      next = _clampNumber(next);
    }

    final text = widget.format?.call(next) ?? _defaultNumberFormat(next);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
    return true;
  }

  double _clampNumber(double value) {
    var result = value;
    if (widget.min case final min? when result < min) result = min;
    if (widget.max case final max? when result > max) result = max;
    return result;
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

  bool get _hasStepModifier {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showsStepper || !widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final composing = _controller.value.composing;
    if ((composing.isValid && !composing.isCollapsed) || _hasStepModifier) {
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

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        _hasStepModifier) {
      return;
    }

    final delta = event.scrollDelta;
    if (delta.dy == 0 || delta.dy.abs() < delta.dx.abs()) return;
    final direction = delta.dy < 0 ? 1 : -1;
    if (!_canStep(direction.toDouble())) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      if (_bump(direction.toDouble())) {
        scrollEvent.respond(allowPlatformDefault: false);
      }
    });
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
              color: widget.enabled ? colors.textPrimary : colors.textDisabled,
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

    final control = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focusNode.requestFocus : null,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleKeyEvent,
        child: SizedBox(
          width: widget.width,
          height: _height,
          child: AnimatedContainer(
            duration: CLMotion.fast,
            curve: Curves.easeOutCubic,
            decoration: clSmoothDecoration(
              color: widget.enabled
                  ? colors.control
                  : colors.control.withValues(alpha: colors.control.a * 0.5),
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? theme.radii.control,
              ),
              // Error fields retain a visible danger outline at rest; focus
              // strengthens the active accent or danger ring.
              side: BorderSide(
                color: _showsError
                    ? colors.danger
                    : focused
                    ? colors.accent
                    : const Color(0x00000000),
                width: focused ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.only(
              left: horizontalPad,
              right: _showsStepper ? 0 : horizontalPad,
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
                  _NumericStepper(
                    key: const Key('cl-text-field-stepper-drag-zone'),
                    height: _height,
                    focused: focused,
                    canStep: (direction) => _canStep(direction.toDouble()),
                    onStep: _bumpSteps,
                    onRequestFocus: _focusNode.requestFocus,
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

    final increasedValue = _semanticSteppedValue(1);
    final decreasedValue = _semanticSteppedValue(-1);
    return Semantics(
      validationResult: _showsError
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      value: increasedValue != null || decreasedValue != null
          ? _controller.text
          : null,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      onIncrease: increasedValue != null ? () => _bump(1) : null,
      onDecrease: decreasedValue != null ? () => _bump(-1) : null,
      child: Listener(
        onPointerSignal: _showsStepper ? _handlePointerSignal : null,
        child: control,
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

class _NumericStepper extends StatefulWidget {
  static const double width = 24;
  static const double arrowWidth = 18;
  static const double arrowHeight = 10;

  final double height;
  final bool focused;
  final bool Function(int direction) canStep;
  final bool Function(int steps) onStep;
  final VoidCallback onRequestFocus;

  const _NumericStepper({
    super.key,
    required this.height,
    required this.focused,
    required this.canStep,
    required this.onStep,
    required this.onRequestFocus,
  });

  @override
  State<_NumericStepper> createState() => _NumericStepperState();
}

class _NumericStepperState extends State<_NumericStepper>
    with WidgetsBindingObserver {
  static const _touchLongPressDelay = Duration(milliseconds: 300);
  static const _repeatDelay = Duration(milliseconds: 500);
  static const _touchRepeatDelay = Duration(milliseconds: 200);
  static const _repeatInterval = Duration(milliseconds: 80);
  static const double _pixelsPerStep = 8;
  static const _precisePointerKinds = <PointerDeviceKind>{
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  Timer? _repeatDelayTimer;
  Timer? _repeatTimer;
  int? _pressedDirection;
  bool _didRepeat = false;
  bool _touchLongPressActive = false;
  bool _touchDragActive = false;
  bool _preciseDragActive = false;
  bool _interactionCanceled = false;
  double _scrubRemainder = 0;
  double _lastTouchOffset = 0;

  bool get _canAdjust => widget.canStep(1) || widget.canStep(-1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_NumericStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.focused && !widget.focused) || !_canAdjust) {
      _cancelInteraction(markCanceled: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancelInteraction(markCanceled: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelInteraction();
    super.dispose();
  }

  void _stopRepeatTimers() {
    _repeatDelayTimer?.cancel();
    _repeatDelayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _cancelInteraction({bool markCanceled = false}) {
    _stopRepeatTimers();
    _pressedDirection = null;
    _didRepeat = false;
    _touchLongPressActive = false;
    _touchDragActive = false;
    _preciseDragActive = false;
    _interactionCanceled = markCanceled;
    _scrubRemainder = 0;
    _lastTouchOffset = 0;
  }

  void _finishInteraction() {
    _cancelInteraction();
    _interactionCanceled = false;
  }

  void _scheduleRepeat(Duration delay) {
    _repeatDelayTimer?.cancel();
    _repeatDelayTimer = Timer(delay, _startRepeating);
  }

  void _startRepeating() {
    _repeatDelayTimer = null;
    final direction = _pressedDirection;
    if (!mounted || _interactionCanceled || direction == null) return;

    _didRepeat = true;
    if (!widget.canStep(direction)) return;
    widget.onRequestFocus();
    if (!widget.onStep(direction) || !widget.canStep(direction)) return;

    _repeatTimer = Timer.periodic(_repeatInterval, (_) {
      if (!mounted ||
          _interactionCanceled ||
          !widget.canStep(direction) ||
          !widget.onStep(direction)) {
        _repeatTimer?.cancel();
        _repeatTimer = null;
      }
    });
  }

  void _handleButtonDown(int direction, PointerDownEvent event) {
    if (!_primaryButtonOnly(event.buttons)) return;
    _stopRepeatTimers();
    _interactionCanceled = false;
    _pressedDirection = direction;
    _didRepeat = false;
    if (event.kind != PointerDeviceKind.touch) {
      _scheduleRepeat(_repeatDelay);
    }
  }

  void _handleButtonTap(int direction) {
    final repeated = _didRepeat;
    _stopRepeatTimers();
    _pressedDirection = null;
    _didRepeat = false;

    if (!_interactionCanceled && !repeated && widget.canStep(direction)) {
      widget.onRequestFocus();
      widget.onStep(direction);
    }
    _interactionCanceled = false;
  }

  void _handleButtonCancel() {
    if (_touchLongPressActive || _preciseDragActive) return;
    _cancelInteraction(markCanceled: true);
  }

  void _handleButtonExit(int direction) {
    if (_pressedDirection == direction &&
        !_touchLongPressActive &&
        !_preciseDragActive) {
      _cancelInteraction(markCanceled: true);
    }
  }

  int? _directionAt(Offset localPosition) {
    if (localPosition.dx < 0 ||
        localPosition.dx >= _NumericStepper.arrowWidth) {
      return null;
    }

    final top = (widget.height - 2 * _NumericStepper.arrowHeight) / 2;
    if (localPosition.dy >= top &&
        localPosition.dy < top + _NumericStepper.arrowHeight) {
      return 1;
    }
    if (localPosition.dy >= top + _NumericStepper.arrowHeight &&
        localPosition.dy < top + 2 * _NumericStepper.arrowHeight) {
      return -1;
    }
    return null;
  }

  void _handleTouchLongPressStart(LongPressStartDetails details) {
    if (!_canAdjust) return;
    _stopRepeatTimers();
    _pressedDirection = null;
    _didRepeat = false;
    _touchLongPressActive = true;
    _touchDragActive = false;
    _preciseDragActive = false;
    _interactionCanceled = false;
    _scrubRemainder = 0;
    _lastTouchOffset = 0;

    widget.onRequestFocus();
    unawaited(HapticFeedback.selectionClick());

    final direction = _directionAt(details.localPosition);
    if (direction != null && widget.canStep(direction)) {
      _pressedDirection = direction;
      _scheduleRepeat(_touchRepeatDelay);
    }
  }

  void _handleTouchLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_touchLongPressActive || _interactionCanceled) return;
    final offset = details.localOffsetFromOrigin;

    if (!_touchDragActive) {
      if (offset.dx.abs() >= _pixelsPerStep &&
          offset.dx.abs() > offset.dy.abs()) {
        _stopRepeatTimers();
        _pressedDirection = null;
        _interactionCanceled = true;
        return;
      }
      if (offset.dy.abs() < _pixelsPerStep ||
          offset.dy.abs() < offset.dx.abs()) {
        return;
      }

      _touchDragActive = true;
      _stopRepeatTimers();
      _pressedDirection = null;
      _scrubRemainder = 0;
      _lastTouchOffset = 0;
    }

    final delta = offset.dy - _lastTouchOffset;
    _lastTouchOffset = offset.dy;
    _applyScrubDelta(delta);
  }

  void _handlePreciseDragStart(DragStartDetails details) {
    if (!_canAdjust) return;
    _stopRepeatTimers();
    _pressedDirection = null;
    _didRepeat = false;
    _touchLongPressActive = false;
    _touchDragActive = false;
    _preciseDragActive = true;
    _interactionCanceled = false;
    _scrubRemainder = 0;
    widget.onRequestFocus();
  }

  void _handlePreciseDragUpdate(DragUpdateDetails details) {
    if (!_preciseDragActive || _interactionCanceled) return;
    _applyScrubDelta(details.primaryDelta ?? 0);
  }

  void _handlePreciseDragEnd(DragEndDetails details) {
    _finishInteraction();
  }

  void _handleTouchLongPressEnd(LongPressEndDetails details) {
    _finishInteraction();
  }

  void _handleTouchLongPressCancel() {
    if (_touchLongPressActive) _finishInteraction();
  }

  void _applyScrubDelta(double pointerDelta) {
    _scrubRemainder -= pointerDelta;
    final steps = (_scrubRemainder / _pixelsPerStep).truncate();
    if (steps == 0) return;

    if (!widget.onStep(steps)) {
      _scrubRemainder = 0;
      return;
    }

    _scrubRemainder -= steps * _pixelsPerStep;
    if (!widget.canStep(steps.sign)) {
      _scrubRemainder = 0;
    }
  }

  Map<Type, GestureRecognizerFactory> _gestureFactories(
    DeviceGestureSettings? gestureSettings,
  ) {
    if (!_canAdjust) return const <Type, GestureRecognizerFactory>{};

    return <Type, GestureRecognizerFactory>{
      _VerticalScrubGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_VerticalScrubGestureRecognizer>(
            () => _VerticalScrubGestureRecognizer(
              debugOwner: this,
              supportedDevices: _precisePointerKinds,
            ),
            (recognizer) {
              recognizer
                ..gestureSettings = gestureSettings
                ..dragStartBehavior = DragStartBehavior.down
                ..onlyAcceptDragOnThreshold = true
                ..onStart = _handlePreciseDragStart
                ..onUpdate = _handlePreciseDragUpdate
                ..onEnd = _handlePreciseDragEnd
                ..onCancel = _finishInteraction;
            },
          ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: _touchLongPressDelay,
              postAcceptSlopTolerance: null,
              supportedDevices: const <PointerDeviceKind>{
                PointerDeviceKind.touch,
              },
              allowedButtonsFilter: _primaryButtonOnly,
              debugOwner: this,
            ),
            (recognizer) {
              recognizer
                ..gestureSettings = gestureSettings
                ..onLongPressStart = _handleTouchLongPressStart
                ..onLongPressMoveUpdate = _handleTouchLongPressMove
                ..onLongPressEnd = _handleTouchLongPressEnd
                ..onLongPressCancel = _handleTouchLongPressCancel;
            },
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canAdjust = _canAdjust;
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

    return ExcludeSemantics(
      child: MouseRegion(
        cursor: canAdjust ? SystemMouseCursors.resizeUpDown : MouseCursor.defer,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          gestures: _gestureFactories(gestureSettings),
          child: SizedBox(
            width: _NumericStepper.width,
            height: widget.height,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChevronButton(
                    key: const Key('cl-text-field-step-up'),
                    up: true,
                    enabled: widget.canStep(1),
                    onPointerDown: (event) => _handleButtonDown(1, event),
                    onTap: () => _handleButtonTap(1),
                    onTapCancel: _handleButtonCancel,
                    onExit: () => _handleButtonExit(1),
                  ),
                  _ChevronButton(
                    key: const Key('cl-text-field-step-down'),
                    up: false,
                    enabled: widget.canStep(-1),
                    onPointerDown: (event) => _handleButtonDown(-1, event),
                    onTap: () => _handleButtonTap(-1),
                    onTapCancel: _handleButtonCancel,
                    onExit: () => _handleButtonExit(-1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _primaryButtonOnly(int buttons) => buttons == kPrimaryButton;

class _VerticalScrubGestureRecognizer extends VerticalDragGestureRecognizer {
  Offset _distance = Offset.zero;
  bool _trackingSequence = false;

  _VerticalScrubGestureRecognizer({super.debugOwner, super.supportedDevices})
    : super(allowedButtonsFilter: _primaryButtonOnly);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!_trackingSequence) {
      _distance = Offset.zero;
      _trackingSequence = true;
    }
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _distance += event.localDelta;
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final hitSlop = switch (pointerDeviceKind) {
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => kPrecisePointerHitSlop,
      _ => computeHitSlop(pointerDeviceKind, gestureSettings),
    };
    return _distance.dy.abs() > hitSlop &&
        _distance.dy.abs() >= _distance.dx.abs();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _trackingSequence = false;
    _distance = Offset.zero;
  }
}

class _ChevronButton extends StatefulWidget {
  final bool up;
  final bool enabled;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback onTap;
  final VoidCallback onTapCancel;
  final VoidCallback onExit;

  const _ChevronButton({
    super.key,
    required this.up,
    required this.enabled,
    required this.onPointerDown,
    required this.onTap,
    required this.onTapCancel,
    required this.onExit,
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() => _hovered = false);
        widget.onExit();
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled ? widget.onPointerDown : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          onTapCancel: widget.enabled ? widget.onTapCancel : null,
          child: SizedBox(
            width: _NumericStepper.arrowWidth,
            height: _NumericStepper.arrowHeight,
            child: Center(
              child: CustomPaint(
                size: const Size(8, 4.5),
                painter: _StepChevronPainter(color: color, up: widget.up),
              ),
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
