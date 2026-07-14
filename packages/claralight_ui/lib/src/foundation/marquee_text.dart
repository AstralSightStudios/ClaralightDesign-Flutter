import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A single-line text label that scrolls only when it exceeds its width.
///
/// Overflowing text waits for [startDelay], then loops left at [velocity]
/// logical pixels per second. The repeated labels are separated by [gap].
class CLMarqueeText extends StatefulWidget {
  const CLMarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 30,
    this.gap = 32,
    this.startDelay = const Duration(seconds: 1),
  }) : assert(velocity > 0),
       assert(gap >= 0);

  final String text;
  final TextStyle? style;
  final double velocity;
  final double gap;
  final Duration startDelay;

  @override
  State<CLMarqueeText> createState() => _CLMarqueeTextState();
}

class _CLMarqueeTextState extends State<CLMarqueeText>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final Key _visibilityKey = UniqueKey();
  Timer? _startTimer;
  Duration _period = Duration.zero;
  bool _overflowing = false;
  bool _visible = false;
  bool _tickerEnabled = true;
  bool _animationsDisabled = false;
  bool _appActive = true;
  bool _started = false;

  bool get _canAnimate =>
      _overflowing &&
      _visible &&
      _tickerEnabled &&
      !_animationsDisabled &&
      _appActive;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_tickerEnabled == tickerEnabled &&
        _animationsDisabled == animationsDisabled) {
      return;
    }
    _tickerEnabled = tickerEnabled;
    _animationsDisabled = animationsDisabled;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CLMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.velocity != widget.velocity ||
        oldWidget.gap != widget.gap ||
        oldWidget.startDelay != widget.startDelay) {
      _resetAnimation();
      _syncAnimation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appActive = state == AppLifecycleState.resumed;
    if (_appActive == appActive) return;
    _appActive = appActive;
    _syncAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction > 0;
    if (_visible == visible) return;
    _visible = visible;
    _syncAnimation();
  }

  void _scheduleLayoutUpdate({
    required bool overflowing,
    required double distance,
  }) {
    final micros = overflowing
        ? (distance / widget.velocity * Duration.microsecondsPerSecond).round()
        : 0;
    final period = Duration(microseconds: micros.clamp(1, 1 << 62).toInt());
    if (_overflowing == overflowing && _period == period) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final changed = _overflowing != overflowing || _period != period;
      _overflowing = overflowing;
      _period = period;
      if (changed) _resetAnimation();
      _syncAnimation();
    });
  }

  void _resetAnimation() {
    _startTimer?.cancel();
    _startTimer = null;
    _controller.stop(canceled: false);
    _controller.value = 0;
    _started = false;
  }

  void _syncAnimation() {
    if (_animationsDisabled) {
      _resetAnimation();
      return;
    }
    if (!_canAnimate) {
      _startTimer?.cancel();
      _startTimer = null;
      _controller.stop(canceled: false);
      return;
    }
    if (_started) {
      if (!_controller.isAnimating) {
        _controller.repeat(period: _period);
      }
      return;
    }
    if (_startTimer != null) return;
    _startTimer = Timer(widget.startDelay, () {
      _startTimer = null;
      if (!mounted || !_canAnimate) return;
      _started = true;
      _controller.repeat(period: _period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final effectiveStyle = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
          locale: locale,
        )..layout();
        final textWidth = painter.width;
        final overflowing =
            constraints.hasBoundedWidth && textWidth > constraints.maxWidth;
        _scheduleLayoutUpdate(
          overflowing: overflowing,
          distance: textWidth + widget.gap,
        );

        final visual = overflowing && !_animationsDisabled
            ? ClipRect(
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        -_controller.value * (textWidth + widget.gap),
                        0,
                      ),
                      child: child,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: effectiveStyle,
                        ),
                        SizedBox(width: widget.gap),
                        Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: effectiveStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: overflowing
                    ? TextOverflow.ellipsis
                    : TextOverflow.clip,
                style: effectiveStyle,
              );

        return SizedBox(
          height: painter.height,
          child: VisibilityDetector(
            key: _visibilityKey,
            onVisibilityChanged: _handleVisibilityChanged,
            child: Semantics(
              label: widget.text,
              excludeSemantics: true,
              child: visual,
            ),
          ),
        );
      },
    );
  }
}
