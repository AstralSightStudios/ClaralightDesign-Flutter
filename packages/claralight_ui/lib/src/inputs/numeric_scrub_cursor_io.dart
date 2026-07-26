import 'dart:io';
import 'dart:math' as math;

import 'package:mouse/mouse.dart' as mouse;

import 'numeric_scrub_cursor_backend.dart';

NumericScrubCursorBackend createNumericScrubCursorBackend() =>
    const _IoNumericScrubCursorBackend();

class _IoNumericScrubCursorBackend implements NumericScrubCursorBackend {
  const _IoNumericScrubCursorBackend();

  @override
  bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  double logicalToSystemScale(double devicePixelRatio) =>
      Platform.isMacOS ? 1 : devicePixelRatio;

  @override
  math.Point<double> getPosition() => mouse.getPosition();

  @override
  void moveTo(math.Point<double> position) => mouse.moveTo(position);
}
