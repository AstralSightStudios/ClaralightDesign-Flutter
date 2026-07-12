import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large value jumps settle without a visible rebound', (
    tester,
  ) async {
    var value = 1000.0;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 300,
                child: CLSlider(
                  min: 0,
                  max: 10000,
                  value: value,
                  onChanged: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );

    final thumb = find.byWidgetPredicate(
      (widget) =>
          widget is Positioned &&
          widget.width == CLSlider.thumbSize &&
          widget.height == CLSlider.thumbSize,
    );
    double thumbLeft() => tester.widget<Positioned>(thumb).left!;

    update(() => value = 9000);
    await tester.pump();

    final positions = <double>[thumbLeft()];
    for (var frame = 0; frame < 90; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      positions.add(thumbLeft());
    }

    final target = (300 - CLSlider.thumbSize) * 0.9;
    expect(positions.last, closeTo(target, 0.05));
    expect(
      positions.reduce((a, b) => a > b ? a : b),
      lessThanOrEqualTo(target + 0.01),
    );
    for (var index = 1; index < positions.length; index++) {
      expect(
        positions[index],
        greaterThanOrEqualTo(positions[index - 1] - 0.01),
      );
    }
  });
}
