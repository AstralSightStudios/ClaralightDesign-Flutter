import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The semantic trend used by [CLAnimatedNumber].
///
/// A trend describes the value change, not a physical screen direction. With
/// [increasing], old digits leave upward and new digits enter from below.
enum CLNumberTrend { automatic, increasing, decreasing }

/// A single-line number whose changed digits transition like SwiftUI's
/// numeric-text content transition.
///
/// The first value is shown without animation. Later changes roll only the
/// changed ASCII digits (`0` through `9`), while matching punctuation, currency
/// symbols, and units remain stable. [formatter] should return one primary
/// numeric value with ordinary prefix, suffix, grouping, or decimal decoration.
/// More complex multi-number strings use deterministic textual matching rather
/// than mathematical field awareness.
class CLAnimatedNumber extends StatelessWidget {
  const CLAnimatedNumber(
    this.value, {
    super.key,
    this.formatter,
    this.style,
    this.alignment = AlignmentDirectional.centerEnd,
    this.trend = CLNumberTrend.automatic,
    this.semanticsLabel,
  }) : assert(
         value == value &&
             value != double.infinity &&
             value != double.negativeInfinity,
         'CLAnimatedNumber requires a finite value.',
       );

  /// The finite value represented by this widget.
  final num value;

  /// Formats [value] for display. Defaults to [num.toString].
  ///
  /// The result must be a single line. Only ASCII digits receive vertical
  /// numeric motion; inserted or removed non-digit graphemes cross-fade.
  final String Function(num value)? formatter;

  /// Optional text style merged over the ambient [DefaultTextStyle].
  ///
  /// Tabular figures are enabled unless the merged style explicitly contains
  /// either the `tnum` or `pnum` OpenType feature.
  final TextStyle? style;

  /// Anchors content inside the widget while its intrinsic width changes.
  ///
  /// The parent still owns the widget's global position. Use an end-aligned or
  /// fixed-width parent when the trailing screen coordinate must remain fixed.
  final AlignmentGeometry alignment;

  /// Overrides the trend inferred from consecutive [value]s.
  final CLNumberTrend trend;

  /// Optional accessible label. Defaults to the formatted number.
  ///
  /// Updates are not exposed as a live region, so rapidly changing counters do
  /// not repeatedly interrupt assistive technology.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final formatted = formatter?.call(value) ?? value.toString();
    assert(
      _isSingleLine(formatted),
      'CLAnimatedNumber.formatter must return a single-line string.',
    );

    final ambientStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = _withDefaultTabularFigures(
      ambientStyle.merge(style),
    );
    final mediaQuery = MediaQuery.maybeOf(context);
    final disableAnimations =
        mediaQuery?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;

    final resolved = _ResolvedNumber(
      value: value,
      formatted: formatted,
      style: effectiveStyle,
      alignment: alignment,
      trend: trend,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      disableAnimations: disableAnimations,
      tickerEnabled: TickerMode.valuesOf(context).enabled,
    );

    return Semantics(
      container: true,
      label: semanticsLabel ?? formatted,
      excludeSemantics: true,
      child: _AnimatedNumberVisual(resolved: resolved),
    );
  }
}

bool _isSingleLine(String text) =>
    !text.contains('\n') &&
    !text.contains('\r') &&
    !text.contains('\u2028') &&
    !text.contains('\u2029');

TextStyle _withDefaultTabularFigures(TextStyle style) {
  final features = style.fontFeatures;
  final hasExplicitFigureWidth =
      features?.any(
        (feature) => feature.feature == 'tnum' || feature.feature == 'pnum',
      ) ??
      false;
  if (hasExplicitFigureWidth) return style;

  return style.copyWith(
    fontFeatures: [...?features, const ui.FontFeature.tabularFigures()],
  );
}

@immutable
class _ResolvedNumber {
  const _ResolvedNumber({
    required this.value,
    required this.formatted,
    required this.style,
    required this.alignment,
    required this.trend,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.disableAnimations,
    required this.tickerEnabled,
  });

  final num value;
  final String formatted;
  final TextStyle style;
  final AlignmentGeometry alignment;
  final CLNumberTrend trend;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final bool disableAnimations;
  final bool tickerEnabled;

  bool get canAnimate => !disableAnimations && tickerEnabled;

  bool hasSameLayoutContext(_ResolvedNumber other) =>
      style == other.style &&
      alignment == other.alignment &&
      textDirection == other.textDirection &&
      textScaler == other.textScaler &&
      locale == other.locale;
}

class _AnimatedNumberVisual extends StatefulWidget {
  const _AnimatedNumberVisual({required this.resolved});

  final _ResolvedNumber resolved;

  @override
  State<_AnimatedNumberVisual> createState() => _AnimatedNumberVisualState();
}

class _AnimatedNumberVisualState extends State<_AnimatedNumberVisual>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final _NumberScene _scene;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
    _scene = _NumberScene(widget.resolved);
  }

  @override
  void didUpdateWidget(covariant _AnimatedNumberVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.resolved;
    final next = widget.resolved;

    final valueChanged = previous.value != next.value;
    final textChanged = previous.formatted != next.formatted;
    final layoutContextChanged = !previous.hasSameLayoutContext(next);

    if (!next.canAnimate || !previous.canAnimate || layoutContextChanged) {
      _stopAndSnap(next);
      return;
    }

    if (!valueChanged) {
      if (textChanged) {
        _stopAndSnap(next);
      } else {
        _scene.updateResolved(next);
      }
      return;
    }

    if (!textChanged) {
      _scene.updateResolved(next);
      return;
    }

    final increasing = switch (next.trend) {
      CLNumberTrend.automatic => next.value > previous.value,
      CLNumberTrend.increasing => true,
      CLNumberTrend.decreasing => false,
    };

    if (!_ticker.isActive) _elapsed = Duration.zero;
    _scene.retarget(next, increasing: increasing, elapsed: _elapsed);
    if (_scene.isAnimating && !_ticker.isActive) _ticker.start();
  }

  void _stopAndSnap(_ResolvedNumber resolved) {
    if (_ticker.isActive) _ticker.stop();
    _elapsed = Duration.zero;
    _scene.snap(resolved);
  }

  void _handleTick(Duration elapsed) {
    _elapsed = elapsed;
    if (_scene.advance(elapsed)) return;

    _ticker.stop();
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AnimatedNumberRender(scene: _scene);
}

class _NumberScene extends ChangeNotifier {
  _NumberScene(this.resolved) {
    _targetLayout = _buildLayout(resolved, previous: null);
    _width = _SpringTrack(_targetLayout.width);
    for (final token in _targetLayout.tokens) {
      _fragments.add(
        _GlyphFragment.resting(layout: _targetLayout, token: token),
      );
    }
  }

  static const double travelFraction = 0.4;
  static const double blurShutter = 1 / 30;
  static const double maxBlurFraction = 1;

  static const int _maxLayersPerSlot = 4;

  _ResolvedNumber resolved;
  late _NumberLayout _targetLayout;
  late _SpringTrack _width;
  final List<_GlyphFragment> _fragments = [];
  final Set<_NumberLayout> _layouts = {};
  int _nextDecorationSlot = 0;

  double get width => math.max(0, _width.value);
  double get height => _targetLayout.height;
  double get alphabeticBaseline => _targetLayout.alphabeticBaseline;
  AlignmentGeometry get alignment => resolved.alignment;
  TextDirection get textDirection => resolved.textDirection;
  List<_GlyphFragment> get fragments => _fragments;
  _NumberLayout get targetLayout => _targetLayout;

  bool get isAnimating =>
      _width.isAnimating ||
      _fragments.any(
        (fragment) =>
            fragment.x.isAnimating ||
            fragment.y.isAnimating ||
            fragment.opacity.isAnimating,
      );

  void updateResolved(_ResolvedNumber next) {
    resolved = next;
  }

  void snap(_ResolvedNumber next) {
    final previousLayout = _targetLayout;
    final nextLayout = _buildLayout(next, previous: previousLayout);
    final oldLayouts = Set<_NumberLayout>.of(_layouts)..add(previousLayout);

    resolved = next;
    _targetLayout = nextLayout;
    _width.snap(nextLayout.width);
    _fragments
      ..clear()
      ..addAll(
        nextLayout.tokens.map(
          (token) => _GlyphFragment.resting(layout: nextLayout, token: token),
        ),
      );

    _layouts
      ..clear()
      ..add(nextLayout);
    for (final layout in oldLayouts) {
      if (!identical(layout, nextLayout)) layout.dispose();
    }
    notifyListeners();
  }

  void retarget(
    _ResolvedNumber next, {
    required bool increasing,
    required Duration elapsed,
  }) {
    _sample(elapsed);

    final previousTarget = _targetLayout;
    final nextLayout = _buildLayout(next, previous: previousTarget);
    final nextBySlot = {
      for (final token in nextLayout.tokens) token.slot: token,
    };
    final used = <_GlyphFragment>{};
    final incomingSign = increasing ? 1.0 : -1.0;
    final outgoingSign = -incomingSign;
    final travel = nextLayout.scaledFontSize * travelFraction;

    for (final token in nextLayout.tokens) {
      final matching = _bestMatch(token, used);
      if (matching != null) {
        used.add(matching);
        matching
          ..layout = nextLayout
          ..token = token
          ..isTarget = true;
        matching.x.retarget(token.relativeLeft, elapsed);
        matching.y.retarget(0, elapsed);
        matching.opacity.retarget(1, elapsed);
        continue;
      }

      final fragment = _GlyphFragment.incoming(
        layout: nextLayout,
        token: token,
        y: token.isDigit ? incomingSign * travel : 0,
      );
      fragment.y.retarget(0, elapsed);
      fragment.opacity.retarget(1, elapsed);
      _fragments.add(fragment);
      used.add(fragment);
    }

    for (final fragment in _fragments) {
      if (used.contains(fragment)) continue;

      final wasTarget = fragment.isTarget;
      fragment.isTarget = false;
      final replacement = nextBySlot[fragment.token.slot];
      if (replacement != null) {
        fragment.x.retarget(replacement.relativeLeft, elapsed);
      }
      if (!wasTarget) continue;

      if (fragment.token.isDigit) {
        fragment.y.retarget(outgoingSign * travel, elapsed);
      }
      fragment.opacity.retarget(0, elapsed);
    }

    resolved = next;
    _targetLayout = nextLayout;
    _width.retarget(nextLayout.width, elapsed);
    _pruneInvisibleAndExcess();
    _disposeUnusedLayouts();
    notifyListeners();
  }

  _GlyphFragment? _bestMatch(_NumberToken token, Set<_GlyphFragment> used) {
    _GlyphFragment? best;
    for (final fragment in _fragments) {
      if (used.contains(fragment) ||
          fragment.token.slot != token.slot ||
          fragment.token.text != token.text) {
        continue;
      }
      if (best == null ||
          (fragment.isTarget && !best.isTarget) ||
          fragment.opacity.value > best.opacity.value) {
        best = fragment;
      }
    }
    return best;
  }

  bool advance(Duration elapsed) {
    final animating = _sample(elapsed);
    _pruneInvisibleAndExcess();
    _disposeUnusedLayouts();

    if (!animating) {
      _width.snap(_width.target);
      for (final fragment in _fragments) {
        fragment
          ..x.snap(fragment.x.target)
          ..y.snap(fragment.y.target)
          ..opacity.snap(fragment.opacity.target);
      }
      _fragments.removeWhere((fragment) => !fragment.isTarget);
      _disposeUnusedLayouts();
    }

    notifyListeners();
    return isAnimating;
  }

  bool _sample(Duration elapsed) {
    var animating = _width.sample(elapsed);
    for (final fragment in _fragments) {
      animating = fragment.x.sample(elapsed) || animating;
      animating = fragment.y.sample(elapsed) || animating;
      animating = fragment.opacity.sample(elapsed) || animating;
    }
    return animating;
  }

  void _pruneInvisibleAndExcess() {
    _fragments.removeWhere(
      (fragment) =>
          !fragment.isTarget &&
          fragment.opacity.target == 0 &&
          fragment.opacity.value <= 0.005,
    );

    final bySlot = <_TokenSlot, List<_GlyphFragment>>{};
    for (final fragment in _fragments) {
      bySlot.putIfAbsent(fragment.token.slot, () => []).add(fragment);
    }
    for (final fragments in bySlot.values) {
      if (fragments.length <= _maxLayersPerSlot) continue;
      final removable =
          fragments.where((fragment) => !fragment.isTarget).toList()
            ..sort((a, b) => a.opacity.value.compareTo(b.opacity.value));
      var excess = fragments.length - _maxLayersPerSlot;
      for (final fragment in removable) {
        if (excess == 0) break;
        _fragments.remove(fragment);
        excess--;
      }
    }
  }

  _NumberLayout _buildLayout(
    _ResolvedNumber configuration, {
    required _NumberLayout? previous,
  }) {
    final layout = _NumberLayout.build(
      configuration,
      previous: previous,
      nextDecorationSlot: () => _nextDecorationSlot++,
    );
    _layouts.add(layout);
    return layout;
  }

  void _disposeUnusedLayouts() {
    final used = <_NumberLayout>{_targetLayout};
    for (final fragment in _fragments) {
      used.add(fragment.layout);
    }
    final unused = _layouts.difference(used).toList(growable: false);
    for (final layout in unused) {
      _layouts.remove(layout);
      layout.dispose();
    }
  }

  @override
  void dispose() {
    for (final layout in _layouts) {
      layout.dispose();
    }
    _layouts.clear();
    super.dispose();
  }
}

class _NumberLayout {
  _NumberLayout({
    required this.painter,
    required this.tokens,
    required this.scaledFontSize,
  }) : width = painter.width,
       height = painter.height,
       alphabeticBaseline = painter.computeDistanceToActualBaseline(
         TextBaseline.alphabetic,
       );

  final TextPainter painter;
  final List<_NumberToken> tokens;
  final double width;
  final double height;
  final double alphabeticBaseline;
  final double scaledFontSize;

  static _NumberLayout build(
    _ResolvedNumber configuration, {
    required _NumberLayout? previous,
    required int Function() nextDecorationSlot,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: configuration.formatted, style: configuration.style),
      maxLines: 1,
      textDirection: configuration.textDirection,
      textScaler: configuration.textScaler,
      locale: configuration.locale,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout();

    final rawTokens = <_RawToken>[];
    var codeUnitOffset = 0;
    for (final grapheme in configuration.formatted.characters) {
      final start = codeUnitOffset;
      codeUnitOffset += grapheme.length;
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: codeUnitOffset,
      );
      final boxes = painter.getBoxesForSelection(
        selection,
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      final rect = _selectionRect(
        painter,
        boxes,
        start: start,
        end: codeUnitOffset,
      );
      rawTokens.add(
        _RawToken(
          text: grapheme,
          rect: Rect.fromLTRB(rect.left, 0, rect.right, painter.height),
          isDigit: _isAsciiDigit(grapheme),
        ),
      );
    }

    final slots = List<_TokenSlot?>.filled(rawTokens.length, null);
    var digitPlace = 0;
    for (var index = rawTokens.length - 1; index >= 0; index--) {
      if (!rawTokens[index].isDigit) continue;
      slots[index] = _TokenSlot.digit(digitPlace++);
    }

    final previousDecorations = previous?.tokens
        .where((token) => !token.isDigit)
        .toList(growable: false);
    var previousSearchEnd = (previousDecorations?.length ?? 0) - 1;
    for (var index = rawTokens.length - 1; index >= 0; index--) {
      final token = rawTokens[index];
      if (token.isDigit) continue;

      _TokenSlot? matchedSlot;
      if (previousDecorations != null) {
        for (var oldIndex = previousSearchEnd; oldIndex >= 0; oldIndex--) {
          final oldToken = previousDecorations[oldIndex];
          if (oldToken.text != token.text) continue;
          matchedSlot = oldToken.slot;
          previousSearchEnd = oldIndex - 1;
          break;
        }
      }
      slots[index] = matchedSlot ?? _TokenSlot.decoration(nextDecorationSlot());
    }

    final resolvedAlignment = configuration.alignment.resolve(
      configuration.textDirection,
    );
    final anchorFraction = (resolvedAlignment.x + 1) / 2;
    final tokens = <_NumberToken>[];
    for (var index = 0; index < rawTokens.length; index++) {
      final raw = rawTokens[index];
      tokens.add(
        _NumberToken(
          text: raw.text,
          rect: raw.rect,
          slot: slots[index]!,
          isDigit: raw.isDigit,
          relativeLeft: raw.rect.left - painter.width * anchorFraction,
        ),
      );
    }

    final nominalFontSize = configuration.style.fontSize ?? 14;
    return _NumberLayout(
      painter: painter,
      tokens: tokens,
      scaledFontSize: configuration.textScaler.scale(nominalFontSize),
    );
  }

  void dispose() => painter.dispose();
}

Rect _selectionRect(
  TextPainter painter,
  List<TextBox> boxes, {
  required int start,
  required int end,
}) {
  if (boxes.isNotEmpty) {
    var left = boxes.first.left;
    var top = boxes.first.top;
    var right = boxes.first.right;
    var bottom = boxes.first.bottom;
    for (final box in boxes.skip(1)) {
      left = math.min(left, box.left);
      top = math.min(top, box.top);
      right = math.max(right, box.right);
      bottom = math.max(bottom, box.bottom);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  final startOffset = painter.getOffsetForCaret(
    TextPosition(offset: start),
    Rect.zero,
  );
  final endOffset = painter.getOffsetForCaret(
    TextPosition(offset: end),
    Rect.zero,
  );
  return Rect.fromLTRB(
    math.min(startOffset.dx, endOffset.dx),
    0,
    math.max(startOffset.dx, endOffset.dx),
    painter.height,
  );
}

bool _isAsciiDigit(String grapheme) =>
    grapheme.length == 1 &&
    grapheme.codeUnitAt(0) >= 0x30 &&
    grapheme.codeUnitAt(0) <= 0x39;

@immutable
class _RawToken {
  const _RawToken({
    required this.text,
    required this.rect,
    required this.isDigit,
  });

  final String text;
  final Rect rect;
  final bool isDigit;
}

@immutable
class _NumberToken {
  const _NumberToken({
    required this.text,
    required this.rect,
    required this.slot,
    required this.isDigit,
    required this.relativeLeft,
  });

  final String text;
  final Rect rect;
  final _TokenSlot slot;
  final bool isDigit;
  final double relativeLeft;
}

@immutable
class _TokenSlot {
  const _TokenSlot._(this.isDigit, this.index);

  const _TokenSlot.digit(int place) : this._(true, place);
  const _TokenSlot.decoration(int id) : this._(false, id);

  final bool isDigit;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _TokenSlot && other.isDigit == isDigit && other.index == index;

  @override
  int get hashCode => Object.hash(isDigit, index);
}

class _GlyphFragment {
  _GlyphFragment._({
    required this.layout,
    required this.token,
    required double x,
    required double y,
    required double opacity,
    required this.isTarget,
  }) : x = _SpringTrack(x, spring: _SpringTrack.structureSpring),
       y = _SpringTrack(y, spring: _SpringTrack.rollSpring),
       opacity = _SpringTrack(opacity, spring: _SpringTrack.fadeSpring);

  factory _GlyphFragment.resting({
    required _NumberLayout layout,
    required _NumberToken token,
  }) => _GlyphFragment._(
    layout: layout,
    token: token,
    x: token.relativeLeft,
    y: 0,
    opacity: 1,
    isTarget: true,
  );

  factory _GlyphFragment.incoming({
    required _NumberLayout layout,
    required _NumberToken token,
    required double y,
  }) => _GlyphFragment._(
    layout: layout,
    token: token,
    x: token.relativeLeft,
    y: y,
    opacity: 0,
    isTarget: true,
  );

  _NumberLayout layout;
  _NumberToken token;
  final _SpringTrack x;
  final _SpringTrack y;
  final _SpringTrack opacity;
  bool isTarget;
}

class _SpringTrack {
  _SpringTrack(this.value, {this.spring = structureSpring})
    : target = value,
      velocity = 0;

  static const rollSpring = SpringDescription(
    mass: 1,
    stiffness: 246.74,
    damping: 25.13,
  );

  static const structureSpring = SpringDescription(
    mass: 1,
    stiffness: 246.74,
    damping: 31.42,
  );

  static const fadeSpring = SpringDescription(
    mass: 1,
    stiffness: 631.65,
    damping: 50.27,
  );

  static const _tolerance = Tolerance(distance: 0.001, velocity: 0.001);

  final SpringDescription spring;

  double value;
  double velocity;
  double target;
  SpringSimulation? _simulation;
  Duration _startedAt = Duration.zero;

  bool get isAnimating => _simulation != null;

  void retarget(double nextTarget, Duration elapsed) {
    sample(elapsed);
    if (_simulation != null && (target - nextTarget).abs() <= 0.000001) {
      return;
    }

    target = nextTarget;
    if ((value - target).abs() <= _tolerance.distance &&
        velocity.abs() <= _tolerance.velocity) {
      snap(target);
      return;
    }

    _simulation = SpringSimulation(
      spring,
      value,
      target,
      velocity,
      snapToEnd: true,
      tolerance: _tolerance,
    );
    _startedAt = elapsed;
  }

  bool sample(Duration elapsed) {
    final simulation = _simulation;
    if (simulation == null) return false;

    final micros = math.max(
      0,
      elapsed.inMicroseconds - _startedAt.inMicroseconds,
    );
    final seconds = micros / Duration.microsecondsPerSecond;
    if (simulation.isDone(seconds)) {
      snap(target);
      return false;
    }

    value = simulation.x(seconds);
    velocity = simulation.dx(seconds);
    return true;
  }

  void snap(double nextValue) {
    value = nextValue;
    target = nextValue;
    velocity = 0;
    _simulation = null;
    _startedAt = Duration.zero;
  }
}

class _AnimatedNumberRender extends LeafRenderObjectWidget {
  const _AnimatedNumberRender({required this.scene});

  final _NumberScene scene;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAnimatedNumber(scene);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAnimatedNumber renderObject,
  ) {
    renderObject.scene = scene;
  }
}

class _RenderAnimatedNumber extends RenderBox {
  _RenderAnimatedNumber(_NumberScene scene) : _scene = scene {
    _scene.addListener(_handleSceneChanged);
  }

  _NumberScene _scene;

  _NumberScene get scene => _scene;
  set scene(_NumberScene value) {
    if (identical(value, _scene)) return;
    _scene.removeListener(_handleSceneChanged);
    _scene = value;
    _scene.addListener(_handleSceneChanged);
    markNeedsLayout();
    markNeedsPaint();
  }

  void _handleSceneChanged() {
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  double computeMinIntrinsicWidth(double height) => scene.width;

  @override
  double computeMaxIntrinsicWidth(double height) => scene.width;

  @override
  double computeMinIntrinsicHeight(double width) => scene.height;

  @override
  double computeMaxIntrinsicHeight(double width) => scene.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(scene.width, scene.height));

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final drySize = computeDryLayout(constraints);
    final resolvedAlignment = scene.alignment.resolve(scene.textDirection);
    final top =
        (drySize.height - scene.height) * ((resolvedAlignment.y + 1) / 2);
    return top +
        scene.targetLayout.painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final resolvedAlignment = scene.alignment.resolve(scene.textDirection);
    final top = (size.height - scene.height) * ((resolvedAlignment.y + 1) / 2);
    return top +
        scene.targetLayout.painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    final canvas = context.canvas;
    final resolvedAlignment = scene.alignment.resolve(scene.textDirection);
    final anchorX = size.width * ((resolvedAlignment.x + 1) / 2);
    final targetTop =
        (size.height - scene.height) * ((resolvedAlignment.y + 1) / 2);
    final targetBaseline = targetTop + scene.alphabeticBaseline;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);

    for (final fragment in scene.fragments) {
      _paintFragment(
        canvas,
        fragment,
        anchorX: anchorX,
        targetBaseline: targetBaseline,
      );
    }

    canvas.restore();
  }

  void _paintFragment(
    Canvas canvas,
    _GlyphFragment fragment, {
    required double anchorX,
    required double targetBaseline,
  }) {
    var opacity = fragment.opacity.value.clamp(0.0, 1.0);
    if (fragment.token.isDigit) {
      final travel =
          fragment.layout.scaledFontSize * _NumberScene.travelFraction;
      if (travel > 0) {
        final remaining = (1 - fragment.y.value.abs() / travel).clamp(0.0, 1.0);
        opacity *= remaining * remaining * (3 - 2 * remaining);
      }
    }
    if (opacity <= 0.001 || fragment.token.rect.isEmpty) return;

    final tokenLeft = anchorX + fragment.x.value;
    final paragraphTop =
        targetBaseline - fragment.layout.alphabeticBaseline + fragment.y.value;
    final paintOffset = Offset(
      tokenLeft - fragment.token.rect.left,
      paragraphTop,
    );
    final tokenRect = fragment.token.rect.shift(paintOffset);

    final sigma = fragment.token.isDigit
        ? math.min(
            fragment.layout.scaledFontSize * _NumberScene.maxBlurFraction,
            fragment.y.velocity.abs() * _NumberScene.blurShutter,
          )
        : 0.0;
    final needsLayer = opacity < 0.999 || sigma > 0.01;

    if (needsLayer) {
      final layerPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity);
      if (sigma > 0.01) {
        layerPaint.imageFilter = ui.ImageFilter.blur(
          sigmaY: sigma,
          tileMode: TileMode.decal,
        );
      }
      canvas.saveLayer(tokenRect.inflate(math.max(1, sigma * 3)), layerPaint);
    } else {
      canvas.save();
    }

    canvas.clipRect(tokenRect);
    fragment.layout.painter.paint(canvas, paintOffset);
    canvas.restore();
  }

  @override
  void dispose() {
    _scene.removeListener(_handleSceneChanged);
    super.dispose();
  }
}
