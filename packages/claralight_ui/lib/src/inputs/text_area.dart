import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../scrolling/scrollable.dart';
import '../theme/theme.dart';

/// A Claralight multiline plain-text input.
///
/// The field is fixed-height by default. Set [maxHeight] above [minHeight] to
/// let it grow with wrapped lines until it reaches the limit, after which the
/// content scrolls internally.
class CLTextArea extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool readOnly;
  final bool error;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextAlign textAlign;
  final CLControlSize size;

  /// Minimum outer height, including content padding.
  final double minHeight;

  /// Maximum outer height. Equal to [minHeight] when omitted.
  final double maxHeight;

  /// Fixed width; null fills the available width.
  final double? width;

  /// Corner radius override; null uses the theme's control radius.
  final double? borderRadius;

  /// Optional accessibility label merged into the editable text semantics.
  final String? semanticLabel;

  const CLTextArea({
    super.key,
    this.controller,
    this.focusNode,
    this.scrollController,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.error = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textAlign = TextAlign.start,
    this.size = CLControlSize.large,
    this.minHeight = 120,
    double? maxHeight,
    this.width,
    this.borderRadius,
    this.semanticLabel,
  }) : maxHeight = maxHeight ?? minHeight,
       assert(minHeight > 0 && minHeight < double.infinity),
       assert(
         maxHeight == null || (maxHeight > 0 && maxHeight < double.infinity),
       ),
       assert(maxHeight == null || maxHeight >= minHeight),
       assert(width == null || (width > 0 && width < double.infinity)),
       assert(
         borderRadius == null ||
             (borderRadius >= 0 && borderRadius < double.infinity),
       );

  /// Precaches the shader used by the progressive scroll-edge effects.
  ///
  /// Invoke this after [WidgetsFlutterBinding.ensureInitialized] and before
  /// `runApp` when a text area may begin with overflowing content.
  static Future<void> precache() => CLScrollable.precache();

  @override
  State<CLTextArea> createState() => _CLTextAreaState();
}

/// Keeps the inherited physics and input policy while making scrollbar
/// suppression survive EditableText's multiline `copyWith(scrollbars: true)`.
class _CLTextAreaScrollBehavior extends ScrollBehavior {
  const _CLTextAreaScrollBehavior(this.delegate);

  final ScrollBehavior delegate;

  @override
  Set<PointerDeviceKind> get dragDevices => delegate.dragDevices;

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      delegate.pointerAxisModifiers;

  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) =>
      delegate.getMultitouchDragStrategy(context);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => delegate.buildOverscrollIndicator(context, child, details);

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      delegate.velocityTrackerBuilder(context);

  @override
  TargetPlatform getPlatform(BuildContext context) =>
      delegate.getPlatform(context);

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      delegate.getScrollPhysics(context);

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => delegate.getKeyboardDismissBehavior(context);

  @override
  ScrollBehavior copyWith({
    bool? scrollbars,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    MultitouchDragStrategy? multitouchDragStrategy,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) => _CLTextAreaScrollBehavior(
    delegate.copyWith(
      scrollbars: false,
      overscroll: overscroll,
      dragDevices: dragDevices,
      multitouchDragStrategy: multitouchDragStrategy,
      pointerAxisModifiers: pointerAxisModifiers,
      physics: physics,
      platform: platform,
      keyboardDismissBehavior: keyboardDismissBehavior,
    ),
  );

  @override
  bool shouldNotify(covariant _CLTextAreaScrollBehavior oldDelegate) =>
      delegate.runtimeType != oldDelegate.delegate.runtimeType ||
      delegate.shouldNotify(oldDelegate.delegate);
}

class _CLTextAreaState extends State<CLTextArea> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _ownsScrollController = false;
  bool _selectionRevealScheduled = false;
  double _layoutTextMaxWidth = double.infinity;
  double _layoutTextTopInset = 0;
  double _layoutBottomSafeInset = 0;
  TextStyle? _layoutTextStyle;
  TextAlign _layoutTextAlign = TextAlign.start;
  TextDirection _layoutTextDirection = TextDirection.ltr;
  TextScaler _layoutTextScaler = TextScaler.noScaling;

  @override
  void initState() {
    super.initState();
    _adoptController();
    _adoptFocusNode();
    _adoptScrollController();
  }

  @override
  void didUpdateWidget(covariant CLTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_handleTextChanged);
      if (_ownsController) _controller.dispose();
      _adoptController();
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _adoptFocusNode();
    }
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsScrollController) _scrollController.dispose();
      _adoptScrollController();
    }
    if (oldWidget.enabled && !widget.enabled) {
      _focusNode.unfocus();
    }
  }

  void _adoptController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  void _adoptFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _adoptScrollController() {
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleSelectionReveal() {
    if (_selectionRevealScheduled || !_focusNode.hasFocus) return;
    _selectionRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionRevealScheduled = false;
      if (!mounted || !_focusNode.hasFocus || !_scrollController.hasClients) {
        return;
      }

      final selection = _controller.selection;
      final style = _layoutTextStyle;
      if (!selection.isValid || style == null) return;
      final text = _controller.text;
      final position = TextPosition(
        offset: selection.extentOffset.clamp(0, text.length),
        affinity: selection.affinity,
      );
      final painter = TextPainter(
        text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
        textAlign: _layoutTextAlign,
        textDirection: _layoutTextDirection,
        textScaler: _layoutTextScaler,
      )..layout(maxWidth: _layoutTextMaxWidth);
      final caretPrototype = Rect.fromLTWH(
        0,
        0,
        2,
        painter.preferredLineHeight,
      );
      final caretOffset = painter.getOffsetForCaret(position, caretPrototype);
      final caretHeight = painter.getFullHeightForCaret(
        position,
        caretPrototype,
      );
      painter.dispose();

      final scrollPosition = _scrollController.position;
      final currentOffset = scrollPosition.pixels;
      final caretTop = _layoutTextTopInset + caretOffset.dy;
      final caretBottom = caretTop + caretHeight;
      final topBoundary = currentOffset + 24;
      final bottomBoundary =
          currentOffset +
          scrollPosition.viewportDimension -
          _layoutBottomSafeInset;
      var targetOffset = currentOffset;
      if (caretTop < topBoundary && currentOffset > 0) {
        targetOffset = caretTop - 24;
      } else if (caretBottom > bottomBoundary) {
        targetOffset =
            caretBottom -
            scrollPosition.viewportDimension +
            _layoutBottomSafeInset;
      }
      targetOffset = targetOffset.clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      );
      if (targetOffset != currentOffset) {
        scrollPosition.jumpTo(targetOffset);
      }
    });
  }

  bool get _showsError => widget.enabled && widget.error;

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  Size _measureText({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;
    final focused = widget.enabled && _focusNode.hasFocus;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final textScaler = MediaQuery.textScalerOf(context);
    final radius = widget.borderRadius ?? theme.radii.control;
    final inset = widget.size == CLControlSize.small ? 10.0 : 12.0;
    final textStyle =
        (widget.size == CLControlSize.large
                ? theme.typography.body
                : theme.typography.callout)
            .copyWith(
              color: widget.enabled ? colors.textPrimary : colors.textDisabled,
            );
    final placeholderStyle = textStyle.copyWith(
      color: widget.enabled ? colors.textHint : colors.textDisabled,
    );
    final borderColor = _showsError
        ? colors.danger
        : focused
        ? colors.accent
        : const Color(0x00000000);

    return Semantics(
      label: widget.semanticLabel,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      validationResult: _showsError
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _focusNode.requestFocus : null,
        child: SizedBox(
          width: widget.width,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textMaxWidth = constraints.hasBoundedWidth
                  ? math.max(0.0, constraints.maxWidth - inset * 2)
                  : double.infinity;
              final measuredText = _controller.text.isEmpty
                  ? widget.placeholder ?? ''
                  : _controller.text;
              final editableHeight = _measureText(
                text: measuredText,
                style: _controller.text.isEmpty ? placeholderStyle : textStyle,
                textAlign: widget.textAlign,
                textDirection: textDirection,
                textScaler: textScaler,
                maxWidth: textMaxWidth,
              ).height;
              final naturalHeight = editableHeight + inset * 2;
              final targetHeight = naturalHeight.clamp(
                widget.minHeight,
                widget.maxHeight,
              );
              _layoutTextMaxWidth = textMaxWidth;
              _layoutTextTopInset = inset;
              _layoutBottomSafeInset = inset;
              _layoutTextStyle = textStyle;
              _layoutTextAlign = widget.textAlign;
              _layoutTextDirection = textDirection;
              _layoutTextScaler = textScaler;
              _scheduleSelectionReveal();

              final field = CupertinoTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: widget.placeholder,
                placeholderStyle: placeholderStyle,
                style: textStyle,
                cursorColor: _showsError ? colors.danger : colors.accent,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                inputFormatters: widget.inputFormatters,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                autocorrect: widget.autocorrect,
                enableSuggestions: widget.enableSuggestions,
                textAlign: widget.textAlign,
                textAlignVertical: TextAlignVertical.top,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                decoration: null,
                padding: EdgeInsets.zero,
                minLines: 1,
                maxLines: null,
                scrollPhysics: const NeverScrollableScrollPhysics(),
                scrollPadding: const EdgeInsets.all(20),
              );

              Widget scrollingRegion = ScrollConfiguration(
                behavior: _CLTextAreaScrollBehavior(
                  ScrollConfiguration.of(context),
                ),
                child: CLScrollable(
                  direction: CLScrollDirection.vertical,
                  blurExtent: const EdgeInsets.symmetric(vertical: 24),
                  blurSigma: const EdgeInsets.symmetric(vertical: 5),
                  padding: EdgeInsets.all(inset),
                  horizontalScrollbar: CLScrollbarVisibility.hidden,
                  verticalScrollbar: CLScrollbarVisibility.auto,
                  verticalController: _scrollController,
                  child: field,
                ),
              );
              if (!widget.enabled) {
                scrollingRegion = IgnorePointer(child: scrollingRegion);
              }

              return AnimatedContainer(
                key: const Key('cl-text-area-surface'),
                height: targetHeight,
                duration: animationsDisabled ? Duration.zero : CLMotion.fast,
                curve: CLMotion.easeOut,
                decoration: clSmoothDecoration(
                  color: widget.enabled
                      ? colors.control
                      : colors.control.withValues(
                          alpha: colors.control.a * 0.5,
                        ),
                  borderRadius: BorderRadius.circular(radius),
                  side: BorderSide(
                    color: borderColor,
                    width: focused ? 1.5 : 1,
                  ),
                ),
                child: CLSmoothClip(
                  borderRadius: BorderRadius.circular(radius),
                  child: scrollingRegion,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
