import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'numeric_scrub_cursor_backend.dart';
import 'numeric_scrub_cursor_stub.dart'
    if (dart.library.io) 'numeric_scrub_cursor_io.dart'
    as platform;

export 'numeric_scrub_cursor_backend.dart';

@visibleForTesting
NumericScrubCursorBackend? debugNumericScrubCursorBackendOverride;

NumericScrubCursorBackend _createBackend() =>
    debugNumericScrubCursorBackendOverride ??
    platform.createNumericScrubCursorBackend();

typedef NumericScrubCursorUpdate = ({
  Offset delta,
  Offset position,
  bool canWrap,
});

class NumericScrubCursorSession {
  NumericScrubCursorSession({NumericScrubCursorBackend? backend})
    : _backend = backend ?? _createBackend();

  static const double edgeInset = 4;

  final NumericScrubCursorBackend _backend;

  math.Point<double>? _preparedStart;
  math.Point<double>? _activeStart;
  Offset? _preparedLocalStart;
  Offset? _activeLocalStart;
  double? _systemUnitsPerLogicalPixel;
  double? _systemOriginX;
  Offset? _pendingWarpSource;
  Offset? _pendingWarpTarget;
  bool _pendingWarpSawStaleEvent = false;
  bool _operational = false;

  void prepare({required bool enabled, required Offset position}) {
    _preparedStart = null;
    _preparedLocalStart = null;
    if (!enabled || !_backend.isSupported) return;
    try {
      _preparedStart = _backend.getPosition();
      _preparedLocalStart = position;
    } on Object {
      _preparedStart = null;
      _preparedLocalStart = null;
    }
  }

  void activate({required bool enabled}) {
    _activeStart = enabled ? _preparedStart : null;
    _activeLocalStart = enabled ? _preparedLocalStart : null;
    _preparedStart = null;
    _preparedLocalStart = null;
    _systemUnitsPerLogicalPixel = null;
    _systemOriginX = null;
    _pendingWarpSource = null;
    _pendingWarpTarget = null;
    _pendingWarpSawStaleEvent = false;
    _operational = _activeStart != null && _activeLocalStart != null;
  }

  NumericScrubCursorUpdate correctUpdate({
    required Offset delta,
    required Offset position,
  }) {
    final target = _pendingWarpTarget;
    if (!_operational || target == null) {
      return (delta: delta, position: position, canWrap: true);
    }

    var synchronized = false;
    final scale = _systemUnitsPerLogicalPixel;
    final originX = _systemOriginX;
    if (scale != null && originX != null) {
      try {
        final systemPosition = _backend.getPosition();
        final systemLocalX = (systemPosition.x - originX) / scale;
        synchronized = (position.dx - systemLocalX).abs() <= edgeInset;
      } on Object {
        synchronized = (position.dx - target.dx).abs() <= edgeInset;
      }
    }

    if (!synchronized) {
      final source = _pendingWarpSource;
      final teleportDelta = source == null ? 0.0 : target.dx - source.dx;
      final isUnsynchronizedTeleport =
          teleportDelta.sign == delta.dx.sign &&
          delta.dx.abs() >= teleportDelta.abs() / 2;
      if (isUnsynchronizedTeleport) {
        _pendingWarpSource = null;
        _pendingWarpTarget = null;
        _pendingWarpSawStaleEvent = false;
        return (
          delta: Offset(position.dx - target.dx, delta.dy),
          position: position,
          canWrap: false,
        );
      }

      _pendingWarpSawStaleEvent = true;
      return (delta: delta, position: position, canWrap: false);
    }

    final hadStaleEvent = _pendingWarpSawStaleEvent;
    _pendingWarpSource = null;
    _pendingWarpTarget = null;
    _pendingWarpSawStaleEvent = false;
    if (hadStaleEvent) {
      return (delta: Offset.zero, position: position, canWrap: false);
    }
    return (
      delta: Offset(position.dx - target.dx, delta.dy),
      position: position,
      canWrap: true,
    );
  }

  void maybeWrap({
    required Offset position,
    required double horizontalDirection,
    required Size viewSize,
    required double devicePixelRatio,
    required bool canIncrease,
    required bool canDecrease,
  }) {
    if (!_operational || horizontalDirection == 0) return;

    final left = edgeInset;
    final right = viewSize.width - edgeInset;
    final span = right - left;
    if (span <= 0) return;

    double? targetX;
    if (horizontalDirection > 0 && canIncrease && position.dx >= right) {
      final overshoot = (position.dx - right) % span;
      targetX = left + overshoot;
    } else if (horizontalDirection < 0 && canDecrease && position.dx <= left) {
      final overshoot = (left - position.dx) % span;
      targetX = right - overshoot;
    }
    if (targetX == null) return;

    try {
      final current = _backend.getPosition();
      final scale = _resolveSystemScale(
        current: current,
        position: position,
        devicePixelRatio: devicePixelRatio,
      );
      if (scale == null) {
        _operational = false;
        return;
      }
      final systemOriginX = current.x - position.dx * scale;
      final target = math.Point<double>(
        systemOriginX + targetX * scale,
        current.y,
      );
      _backend.moveTo(target);
      _systemOriginX = systemOriginX;
      _pendingWarpSource = position;
      _pendingWarpTarget = Offset(targetX, position.dy);
      _pendingWarpSawStaleEvent = false;
    } on Object {
      _operational = false;
      _pendingWarpSource = null;
      _pendingWarpTarget = null;
    }
  }

  double? _resolveSystemScale({
    required math.Point<double> current,
    required Offset position,
    required double devicePixelRatio,
  }) {
    final resolved = _systemUnitsPerLogicalPixel;
    if (resolved != null) return resolved;

    final systemStart = _activeStart!;
    final localStart = _activeLocalStart!;
    final logicalDistance = position.dx - localStart.dx;
    final systemDistance = current.x - systemStart.x;
    if (logicalDistance.abs() >= 8) {
      final measured = systemDistance / logicalDistance;
      if (measured.isFinite && measured >= 0.25 && measured <= 8) {
        _systemUnitsPerLogicalPixel = measured;
        return measured;
      }
    }

    final fallback = _backend.logicalToSystemScale(devicePixelRatio);
    if (!fallback.isFinite || fallback <= 0) return null;
    _systemUnitsPerLogicalPixel = fallback;
    return fallback;
  }

  void finish() {
    final start = _activeStart;
    _preparedStart = null;
    _activeStart = null;
    _preparedLocalStart = null;
    _activeLocalStart = null;
    _systemUnitsPerLogicalPixel = null;
    _systemOriginX = null;
    _pendingWarpSource = null;
    _pendingWarpTarget = null;
    _pendingWarpSawStaleEvent = false;
    _operational = false;
    if (start == null) return;
    try {
      _backend.moveTo(start);
    } on Object {
      // Cursor movement is best-effort; numeric scrubbing must keep working.
    }
  }
}
