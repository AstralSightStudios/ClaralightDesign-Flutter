import 'dart:io';
import 'dart:ui' as ui;

import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toolbar frost visual probe', (tester) async {
    const boundaryKey = Key('boundary');
    const colors = <Color>[
      Color(0xFFFF4D6D),
      Color(0xFFFFB703),
      Color(0xFF43AA8B),
      Color(0xFF277DA1),
      Color(0xFF7B2CBF),
      Color(0xFFF72585),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 480,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < 18; index++)
                      Expanded(
                        child: ColoredBox(color: colors[index % colors.length]),
                      ),
                  ],
                ),
                Center(
                  child: CLToolbar(
                    dividers: true,
                    children: [
                      for (final icon in const [
                        Icons.image_outlined,
                        Icons.title_rounded,
                        Icons.data_usage_rounded,
                        Icons.auto_awesome_outlined,
                      ])
                        CLIconButton(
                          icon: icon,
                          size: CLControlSize.medium,
                          selected: icon == Icons.data_usage_rounded,
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/claralight-toolbar-frost-before.png').writeAsBytes(
        bytes!.buffer.asUint8List(),
      );
    });
  });
}
