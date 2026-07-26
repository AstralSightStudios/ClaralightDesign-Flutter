import 'dart:math' as math;

import 'numeric_scrub_cursor_backend.dart';

NumericScrubCursorBackend createNumericScrubCursorBackend() =>
    const _UnsupportedNumericScrubCursorBackend();

class _UnsupportedNumericScrubCursorBackend
    implements NumericScrubCursorBackend {
  const _UnsupportedNumericScrubCursorBackend();

  @override
  bool get isSupported => false;

  @override
  double logicalToSystemScale(double devicePixelRatio) => 1;

  @override
  math.Point<double> getPosition() =>
      throw UnsupportedError('System cursor movement is unavailable');

  @override
  void moveTo(math.Point<double> position) =>
      throw UnsupportedError('System cursor movement is unavailable');
}
