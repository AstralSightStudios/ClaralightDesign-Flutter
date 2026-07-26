import 'dart:math' as math;

abstract interface class NumericScrubCursorBackend {
  bool get isSupported;

  double logicalToSystemScale(double devicePixelRatio);

  math.Point<double> getPosition();

  void moveTo(math.Point<double> position);
}
