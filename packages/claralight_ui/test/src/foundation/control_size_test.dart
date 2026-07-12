import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('control sizes expose the standard control heights', () {
    expect(CLControlSize.small.controlHeight, 28);
    expect(CLControlSize.medium.controlHeight, 36);
    expect(CLControlSize.large.controlHeight, 44);
  });
}
