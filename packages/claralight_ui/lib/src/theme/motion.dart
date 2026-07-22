import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Context-free Claralight motion tokens.
///
/// Component-specific [SpringDescription]s remain local because they encode
/// distinct physical interactions rather than interchangeable timing values.
abstract final class CLMotion {
  /// Small control feedback and compact overlay reveal.
  static const Duration fast = Duration(milliseconds: 140);

  /// Standard finite UI transition.
  static const Duration standard = Duration(milliseconds: 160);

  /// Non-moving opacity feedback retained under reduced motion.
  static const Duration reducedFade = Duration(milliseconds: 125);

  /// Strong deceleration for finite entrances and state changes.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong acceleration for finite exits.
  static const Curve easeIn = Cubic(0.32, 0, 0.67, 0);

  /// Strong symmetric movement curve.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// iOS-like drawer/sheet movement curve.
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  /// Existing Claralight small-overshoot route entrance.
  static const Curve springOut = _CLSpringOutCurve();
}

class _CLSpringOutCurve extends Curve {
  const _CLSpringOutCurve();

  @override
  double transformInternal(double t) {
    const omega = 9.2;
    const zeta = 0.82;
    final decay = math.exp(-zeta * omega * t);
    final freq = omega * math.sqrt(1 - zeta * zeta);
    return 1 -
        decay *
            (math.cos(freq * t) + (zeta * omega / freq) * math.sin(freq * t));
  }
}
