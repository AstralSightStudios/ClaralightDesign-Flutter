import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes exact motion durations through the public package', () {
    expect(CLMotion.fast, const Duration(milliseconds: 140));
    expect(CLMotion.standard, const Duration(milliseconds: 160));
    expect(CLMotion.reducedFade, const Duration(milliseconds: 125));
  });

  test('exposes the approved cubic vocabulary exactly', () {
    const expectedCurves = <Curve>[
      Cubic(0.23, 1, 0.32, 1),
      Cubic(0.32, 0, 0.67, 0),
      Cubic(0.77, 0, 0.175, 1),
      Cubic(0.32, 0.72, 0, 1),
    ];
    const actualCurves = <Curve>[
      CLMotion.easeOut,
      CLMotion.easeIn,
      CLMotion.easeInOut,
      CLMotion.drawer,
    ];

    for (var i = 0; i < actualCurves.length; i++) {
      for (final sample in const [0.1, 0.5, 0.9]) {
        expect(
          actualCurves[i].transform(sample),
          expectedCurves[i].transform(sample),
          reason: 'curve $i at $sample',
        );
      }
    }
  });

  test('spring-out preserves its endpoints and restrained overshoot', () {
    expect(CLMotion.springOut.transform(0), 0);
    expect(CLMotion.springOut.transform(1), 1);

    final earlySample = CLMotion.springOut.transform(0.1);
    final overshootSample = CLMotion.springOut.transform(0.5);
    expect(earlySample, closeTo(0.2547974628486658, 1e-12));
    expect(overshootSample, greaterThan(1));
    expect(overshootSample, lessThan(1.05));
  });
}
