import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

import '../foundation/shape.dart';

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
  State<CLEdgeEffects> createState() => _CLEdgeEffectsState();
}

class _CLEdgeEffectsState extends State<CLEdgeEffects>
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
  ui.Image? _blurTexture;
  Size? _blurTextureSize;
  EdgeInsets? _blurTextureExtent;
  EdgeInsets? _blurTextureSigma;
  EdgeInsets? _blurTextureActivation;

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
            final hasDimensions =
                (widget.horizontalAxisDirection == null ||
                    (_horizontalPosition?.hasContentDimensions ?? false)) &&
                (widget.verticalAxisDirection == null ||
                    (_verticalPosition?.hasContentDimensions ?? false));
            if (activation != EdgeInsets.zero && hasDimensions) {
              final viewportSize = Size(
                _horizontalPosition?.viewportDimension ?? constraints.maxWidth,
                _verticalPosition?.viewportDimension ?? constraints.maxHeight,
              );
              final globalSigma = _globalSigma(
                widget.blurExtent,
                widget.blurSigma,
              );
              if (globalSigma > 0 && !viewportSize.isEmpty) {
                final blurTexture = _getBlurTexture(
                  viewportSize,
                  extent: widget.blurExtent,
                  sigma: widget.blurSigma,
                  activation: activation,
                  globalSigma: globalSigma,
                );
                result = ProgressiveBlurWidget.custom(
                  sigma: globalSigma,
                  blurTexture: blurTexture,
                  child: result,
                );
              } else {
                _replaceBlurTexture(null);
              }
            } else {
              _replaceBlurTexture(null);
            }
            if (activation != EdgeInsets.zero) {
              result = ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => _createMaskShader(
                  bounds,
                  extent: widget.blurExtent,
                  activation: activation,
                ),
                child: result,
              );
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

  ui.Image _getBlurTexture(
    Size size, {
    required EdgeInsets extent,
    required EdgeInsets sigma,
    required EdgeInsets activation,
    required double globalSigma,
  }) {
    if (_blurTexture != null &&
        _blurTextureSize == size &&
        _blurTextureExtent == extent &&
        _blurTextureSigma == sigma &&
        _blurTextureActivation == activation) {
      return _blurTexture!;
    }

    _blurTextureSize = size;
    _blurTextureExtent = extent;
    _blurTextureSigma = sigma;
    _blurTextureActivation = activation;
    final texture = _createBlurTexture(
      size,
      extent: extent,
      sigma: sigma,
      activation: activation,
      globalSigma: globalSigma,
    );
    _replaceBlurTexture(texture);
    return texture;
  }

  void _replaceBlurTexture(ui.Image? texture) {
    if (identical(_blurTexture, texture)) return;
    final oldTexture = _blurTexture;
    _blurTexture = texture;
    if (texture == null) {
      _blurTextureSize = null;
      _blurTextureExtent = null;
      _blurTextureSigma = null;
      _blurTextureActivation = null;
    }
    if (oldTexture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldTexture.dispose());
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
    _blurTexture?.dispose();
    _blurTexture = null;
    super.dispose();
  }
}

double _globalSigma(EdgeInsets extent, EdgeInsets sigma) {
  var result = 0.0;
  if (extent.left > 0) result = math.max(result, sigma.left);
  if (extent.top > 0) result = math.max(result, sigma.top);
  if (extent.right > 0) result = math.max(result, sigma.right);
  if (extent.bottom > 0) result = math.max(result, sigma.bottom);
  return result;
}

ui.Image _createBlurTexture(
  Size logicalSize, {
  required EdgeInsets extent,
  required EdgeInsets sigma,
  required EdgeInsets activation,
  required double globalSigma,
}) {
  final width = math.min(512, math.max(1, logicalSize.width.ceil()));
  final height = math.min(512, math.max(1, logicalSize.height.ceil()));
  final scaleX = width / logicalSize.width;
  final scaleY = height / logicalSize.height;
  final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xff000000), BlendMode.src);

  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(extent.left * scaleX, 0),
    activation: activation.left,
    sigma: sigma.left,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset(width.toDouble(), 0),
    end: Offset(width - extent.right * scaleX, 0),
    activation: activation.right,
    sigma: sigma.right,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(0, extent.top * scaleY),
    activation: activation.top,
    sigma: sigma.top,
    globalSigma: globalSigma,
  );
  _drawBlurGradient(
    canvas,
    bounds,
    start: Offset(0, height.toDouble()),
    end: Offset(0, height - extent.bottom * scaleY),
    activation: activation.bottom,
    sigma: sigma.bottom,
    globalSigma: globalSigma,
  );

  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

void _drawBlurGradient(
  Canvas canvas,
  Rect bounds, {
  required Offset start,
  required Offset end,
  required double activation,
  required double sigma,
  required double globalSigma,
}) {
  if (activation <= 0 || sigma <= 0 || start == end) return;
  const sampleCount = 16;
  final colors = <Color>[];
  final stops = <double>[];
  for (var sample = 0; sample <= sampleCount; sample += 1) {
    final position = sample / sampleCount;
    final easedPosition = Curves.easeOut.transform(position);
    final effectiveSigma = sigma * activation * (1 - easedPosition);
    final value = (255 * math.sqrt(effectiveSigma / globalSigma)).round();
    colors.add(Color.fromARGB(255, value, value, value));
    stops.add(position);
  }
  final paint = Paint()
    ..shader = ui.Gradient.linear(start, end, colors, stops, TileMode.clamp)
    ..blendMode = BlendMode.lighten;
  canvas.drawRect(bounds, paint);
}

ui.Shader _createMaskShader(
  Rect bounds, {
  required EdgeInsets extent,
  required EdgeInsets activation,
}) {
  final image = _createMaskTexture(bounds.size, extent, activation);
  final transform = Matrix4.diagonal3Values(
    bounds.width / image.width,
    bounds.height / image.height,
    1,
  )..setTranslationRaw(bounds.left, bounds.top, 0);
  final shader = ui.ImageShader(
    image,
    ui.TileMode.clamp,
    ui.TileMode.clamp,
    transform.storage,
    filterQuality: FilterQuality.low,
  );
  image.dispose();
  return shader;
}

ui.Image _createMaskTexture(
  Size logicalSize,
  EdgeInsets extent,
  EdgeInsets activation,
) {
  final width = math.min(512, math.max(1, logicalSize.width.ceil()));
  final height = math.min(512, math.max(1, logicalSize.height.ceil()));
  final scaleX = width / logicalSize.width;
  final scaleY = height / logicalSize.height;
  final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xffffffff), BlendMode.src);

  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(extent.left * scaleX, 0),
    activation: activation.left,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset(width.toDouble(), 0),
    end: Offset(width - extent.right * scaleX, 0),
    activation: activation.right,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset.zero,
    end: Offset(0, extent.top * scaleY),
    activation: activation.top,
  );
  _drawMaskGradient(
    canvas,
    bounds,
    start: Offset(0, height.toDouble()),
    end: Offset(0, height - extent.bottom * scaleY),
    activation: activation.bottom,
  );

  final picture = recorder.endRecording();
  final grayscale = picture.toImageSync(width, height);
  picture.dispose();

  final alphaRecorder = ui.PictureRecorder();
  final alphaCanvas = Canvas(alphaRecorder);
  final alphaPaint = Paint()
    ..colorFilter = const ColorFilter.matrix([
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      1,
      0,
      0,
      0,
      0,
    ]);
  alphaCanvas.drawImage(grayscale, Offset.zero, alphaPaint);
  final alphaPicture = alphaRecorder.endRecording();
  final image = alphaPicture.toImageSync(width, height);
  alphaPicture.dispose();
  grayscale.dispose();
  return image;
}

void _drawMaskGradient(
  Canvas canvas,
  Rect bounds, {
  required Offset start,
  required Offset end,
  required double activation,
}) {
  if (activation <= 0 || start == end) return;
  const sampleCount = 16;
  final colors = <Color>[];
  final stops = <double>[];
  for (var sample = 0; sample <= sampleCount; sample += 1) {
    final position = sample / sampleCount;
    final easedPosition = Curves.easeOut.transform(position);
    final value = (255 * (1 - activation * (1 - easedPosition))).round();
    colors.add(Color.fromARGB(255, value, value, value));
    stops.add(position);
  }
  final paint = Paint()
    ..shader = ui.Gradient.linear(start, end, colors, stops, TileMode.clamp)
    ..blendMode = BlendMode.darken;
  canvas.drawRect(bounds, paint);
}
