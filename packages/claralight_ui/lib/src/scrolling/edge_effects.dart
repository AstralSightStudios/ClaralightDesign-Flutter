import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

import '../foundation/shape.dart';

@immutable
class _EdgeAtlasKey {
  const _EdgeAtlasKey(this.size, this.extent);

  final Size size;
  final EdgeInsets extent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EdgeAtlasKey && size == other.size && extent == other.extent;

  @override
  int get hashCode => Object.hash(size, extent);
}

class _EdgeAtlasEntry {
  const _EdgeAtlasEntry(this.key, this.image);

  final _EdgeAtlasKey key;
  final ui.Image image;
}

/// Progressive edge blur and alpha mask driven by one or two scroll
/// controllers.
///
/// Internal component shared by [CLScrollable] and `CLList`. A null
/// [horizontalAxisDirection] or [verticalAxisDirection] disables that axis
/// entirely; the corresponding physical edges never activate.
class CLEdgeEffects extends StatefulWidget {
  const CLEdgeEffects({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.horizontalAxisDirection,
    required this.verticalAxisDirection,
    required this.blurExtent,
    required this.blurSigma,
    required this.borderRadius,
    required this.child,
  });

  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final AxisDirection? horizontalAxisDirection;
  final AxisDirection? verticalAxisDirection;
  final EdgeInsets blurExtent;
  final EdgeInsets blurSigma;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<CLEdgeEffects> createState() => CLEdgeEffectsState();
}

class CLEdgeEffectsState extends State<CLEdgeEffects>
    with TickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 160);

  static const _left = 0;
  static const _top = 1;
  static const _right = 2;
  static const _bottom = 3;

  late final List<AnimationController> _controllers;
  late final Listenable _animation;
  final List<bool> _targets = List<bool>.filled(4, false);
  bool _disableAnimations = false;
  bool _updateScheduled = false;

  /// Whether the effect wrappers (blur + mask) are mounted around the child.
  ///
  /// This is deliberately driven by *scrollability* (whether the position has
  /// a scrollable extent) rather than by the animated activation: mounting
  /// and unmounting swaps the subtree around the scrollable, which recreates
  /// the scrollable's state and resets its scroll offset. Scrollability only
  /// changes when content or viewport sizes change — never mid-gesture — so
  /// the subtree stays structurally stable while scrolling. While a position
  /// is momentarily unattached or unmeasured, the previous value is kept.
  bool _effectsMounted = false;
  bool _effectsMountUpdateScheduled = false;
  final List<_EdgeAtlasEntry> _atlasCache = <_EdgeAtlasEntry>[];

  /// Number of geometry atlases built by this state.
  @visibleForTesting
  int atlasBuildCount = 0;

  /// Number of geometry atlas lookups served by this state.
  @visibleForTesting
  int atlasHitCount = 0;

  ScrollPosition? _horizontalPosition;
  ScrollPosition? _verticalPosition;
  bool _positionSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (_) => AnimationController(vsync: this, duration: _transitionDuration),
    );
    _animation = Listenable.merge(_controllers);
    _addControllerListeners();
    _schedulePositionSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      for (var index = 0; index < _controllers.length; index += 1) {
        _controllers[index].value = _targets[index] ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant CLEdgeEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horizontalController != widget.horizontalController ||
        oldWidget.verticalController != widget.verticalController) {
      oldWidget.horizontalController?.removeListener(_handleControllerChanged);
      oldWidget.verticalController?.removeListener(_handleControllerChanged);
      _removePositionListeners();
      _addControllerListeners();
      _schedulePositionSync();
    } else if (oldWidget.horizontalAxisDirection !=
            widget.horizontalAxisDirection ||
        oldWidget.verticalAxisDirection != widget.verticalAxisDirection) {
      _scheduleTargetUpdate();
    }
  }

  void _addControllerListeners() {
    widget.horizontalController?.addListener(_handleControllerChanged);
    widget.verticalController?.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    _schedulePositionSync();
  }

  void _schedulePositionSync() {
    if (_positionSyncScheduled) return;
    _positionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSyncScheduled = false;
      if (!mounted) return;
      _syncPositionListeners();
    });
  }

  void _syncPositionListeners() {
    final horizontal = widget.horizontalController?.hasClients == true
        ? widget.horizontalController!.position
        : null;
    final vertical = widget.verticalController?.hasClients == true
        ? widget.verticalController!.position
        : null;
    if (_horizontalPosition != horizontal) {
      _horizontalPosition?.removeListener(_updateTargets);
      _horizontalPosition = horizontal;
      _horizontalPosition?.addListener(_updateTargets);
    }
    if (_verticalPosition != vertical) {
      _verticalPosition?.removeListener(_updateTargets);
      _verticalPosition = vertical;
      _verticalPosition?.addListener(_updateTargets);
    }
    _updateTargets();
  }

  void _removePositionListeners() {
    _horizontalPosition?.removeListener(_updateTargets);
    _verticalPosition?.removeListener(_updateTargets);
    _horizontalPosition = null;
    _verticalPosition = null;
  }

  void _scheduleTargetUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updateTargets();
    });
  }

  void _updateTargets() {
    final horizontal = _horizontalPosition;
    final vertical = _verticalPosition;
    _scheduleEffectsMountUpdate();

    if (widget.horizontalAxisDirection != null &&
        horizontal != null &&
        horizontal.hasContentDimensions) {
      final reversed = axisDirectionIsReversed(widget.horizontalAxisDirection!);
      final before =
          horizontal.pixels >
          horizontal.minScrollExtent + precisionErrorTolerance;
      final after =
          horizontal.pixels <
          horizontal.maxScrollExtent - precisionErrorTolerance;
      _setTarget(
        _left,
        widget.blurExtent.left > 0 && (reversed ? after : before),
      );
      _setTarget(
        _right,
        widget.blurExtent.right > 0 && (reversed ? before : after),
      );
    } else {
      _setTarget(_left, false);
      _setTarget(_right, false);
    }

    if (widget.verticalAxisDirection != null &&
        vertical != null &&
        vertical.hasContentDimensions) {
      final reversed = axisDirectionIsReversed(widget.verticalAxisDirection!);
      final before =
          vertical.pixels > vertical.minScrollExtent + precisionErrorTolerance;
      final after =
          vertical.pixels < vertical.maxScrollExtent - precisionErrorTolerance;
      _setTarget(
        _top,
        widget.blurExtent.top > 0 && (reversed ? after : before),
      );
      _setTarget(
        _bottom,
        widget.blurExtent.bottom > 0 && (reversed ? before : after),
      );
    } else {
      _setTarget(_top, false);
      _setTarget(_bottom, false);
    }
  }

  void _scheduleEffectsMountUpdate() {
    if (_effectsMountUpdateScheduled) return;
    _effectsMountUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _effectsMountUpdateScheduled = false;
      if (mounted) _updateEffectsMount();
    });
  }

  /// Recomputes [_effectsMounted] from the positions' scrollable extents (see
  /// the field's documentation). Positions that are unattached or not yet
  /// measured do not change the current value.
  void _updateEffectsMount() {
    var scrollable = false;
    var decided = widget.blurExtent != EdgeInsets.zero;
    final horizontal = _horizontalPosition;
    final vertical = _verticalPosition;
    if (widget.horizontalAxisDirection != null) {
      if (horizontal == null || !horizontal.hasContentDimensions) {
        decided = false;
      } else {
        scrollable =
            scrollable || horizontal.maxScrollExtent > precisionErrorTolerance;
      }
    }
    if (widget.verticalAxisDirection != null) {
      if (vertical == null || !vertical.hasContentDimensions) {
        decided = false;
      } else {
        scrollable =
            scrollable || vertical.maxScrollExtent > precisionErrorTolerance;
      }
    }
    if (!decided || scrollable == _effectsMounted) return;
    setState(() => _effectsMounted = scrollable);
  }

  void _setTarget(int index, bool target) {
    if (_targets[index] == target) return;
    _targets[index] = target;
    final controller = _controllers[index];
    if (_disableAnimations) {
      controller.value = target ? 1 : 0;
      return;
    }
    controller.animateTo(
      target ? 1 : 0,
      duration: _transitionDuration,
      curve: target ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final activation = EdgeInsets.fromLTRB(
          _controllers[_left].value,
          _controllers[_top].value,
          _controllers[_right].value,
          _controllers[_bottom].value,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            Widget result = child!;
            if (_effectsMounted) {
              final viewportSize = Size(
                constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : _horizontalPosition?.viewportDimension ?? 0,
                constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : _verticalPosition?.viewportDimension ?? 0,
              );
              final atlas = _getAtlas(viewportSize, widget.blurExtent);
              result = ProgressiveBlurWidget.multiLayer(
                blurAtlas: atlas,
                layerSigmas: ProgressiveBlurLayerValues(
                  layer0: widget.blurSigma.left,
                  layer1: widget.blurSigma.top,
                  layer2: widget.blurSigma.right,
                  layer3: widget.blurSigma.bottom,
                ),
                layerActivations: ProgressiveBlurLayerValues(
                  layer0: activation.left,
                  layer1: activation.top,
                  layer2: activation.right,
                  layer3: activation.bottom,
                ),
                maskAlpha: true,
                child: result,
              );
            } else {
              _clearAtlasCache();
            }
            if (widget.borderRadius != BorderRadius.zero) {
              result = CLSmoothClip(
                borderRadius: widget.borderRadius,
                child: result,
              );
            }
            return result;
          },
        );
      },
    );
  }

  ui.Image _getAtlas(Size size, EdgeInsets extent) {
    final key = _EdgeAtlasKey(size, extent);
    for (var index = 0; index < _atlasCache.length; index += 1) {
      final entry = _atlasCache[index];
      if (entry.key != key) continue;
      atlasHitCount += 1;
      if (index != 0) {
        _atlasCache
          ..removeAt(index)
          ..insert(0, entry);
      }
      return entry.image;
    }

    atlasBuildCount += 1;
    final entry = _EdgeAtlasEntry(key, _createEdgeAtlas(size, extent));
    _atlasCache.insert(0, entry);
    if (_atlasCache.length > 2) {
      final evicted = _atlasCache.removeLast();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        evicted.image.dispose();
      });
    }
    return entry.image;
  }

  void _clearAtlasCache() {
    if (_atlasCache.isEmpty) return;
    final entries = List<_EdgeAtlasEntry>.of(_atlasCache);
    _atlasCache.clear();
    for (final entry in entries) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        entry.image.dispose();
      });
    }
  }

  @override
  void dispose() {
    widget.horizontalController?.removeListener(_handleControllerChanged);
    widget.verticalController?.removeListener(_handleControllerChanged);
    _removePositionListeners();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final entry in _atlasCache) {
      entry.image.dispose();
    }
    _atlasCache.clear();
    super.dispose();
  }
}

ui.Image _createEdgeAtlas(Size logicalSize, EdgeInsets extent) {
  final width = math.min(512, math.max(1, logicalSize.width.ceil()));
  final height = math.min(512, math.max(1, logicalSize.height.ceil()));
  final scaleX = logicalSize.width == 0 ? 0 : width / logicalSize.width;
  final scaleY = logicalSize.height == 0 ? 0 : height / logicalSize.height;
  final cellWidth = width.toDouble();
  final cellHeight = height.toDouble();
  final atlasWidth = width * 2;
  final atlasHeight = height * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xff000000), BlendMode.src);

  // The atlas is row-major: left, top, right, bottom. Every cell is an
  // opaque red square-root strength map; activation and sigma are uniforms.
  _drawAtlasGradient(
    canvas,
    Rect.fromLTWH(0, 0, cellWidth, cellHeight),
    start: Offset.zero,
    end: Offset(extent.left * scaleX, 0),
  );
  _drawAtlasGradient(
    canvas,
    Rect.fromLTWH(cellWidth, 0, cellWidth, cellHeight),
    start: Offset(cellWidth, 0),
    end: Offset(cellWidth, extent.top * scaleY),
  );
  _drawAtlasGradient(
    canvas,
    Rect.fromLTWH(0, cellHeight, cellWidth, cellHeight),
    start: Offset(cellWidth, cellHeight),
    end: Offset(cellWidth - extent.right * scaleX, cellHeight),
  );
  _drawAtlasGradient(
    canvas,
    Rect.fromLTWH(cellWidth, cellHeight, cellWidth, cellHeight),
    start: Offset(cellWidth * 2, cellHeight * 2),
    end: Offset(cellWidth * 2, cellHeight * 2 - extent.bottom * scaleY),
  );

  final picture = recorder.endRecording();
  final image = picture.toImageSync(atlasWidth, atlasHeight);
  picture.dispose();
  return image;
}

void _drawAtlasGradient(
  Canvas canvas,
  Rect bounds, {
  required Offset start,
  required Offset end,
}) {
  if (start == end) return;
  const sampleCount = 16;
  final colors = <Color>[];
  final stops = <double>[];
  for (var sample = 0; sample <= sampleCount; sample += 1) {
    final position = sample / sampleCount;
    final strength = math.sqrt(1 - Curves.easeOut.transform(position));
    colors.add(Color.fromARGB(255, (strength * 255).round(), 0, 0));
    stops.add(position);
  }
  final paint = Paint()
    ..shader = ui.Gradient.linear(start, end, colors, stops, TileMode.clamp);
  canvas.drawRect(bounds, paint);
}
