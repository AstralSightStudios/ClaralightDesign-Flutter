import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _openSheetKey = Key('open-sheet');
const _sheetContentKey = Key('sheet-content');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSheetHost({
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    double contentHeight = 100,
  }) {
    return MaterialApp(
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            viewPadding: viewPadding,
            viewInsets: viewInsets,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: _openSheetKey,
            onPressed: () => CLSheet.show<void>(
              context,
              showGrabber: false,
              child: SizedBox(key: _sheetContentKey, height: contentHeight),
            ),
            child: const Text('Open sheet'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(_openSheetKey));
    await tester.pumpAndSettle();
  }

  testWidgets('route keeps its duration and spring position sample', (
    tester,
  ) async {
    await tester.pumpWidget(buildSheetHost());

    await tester.tap(find.byKey(_openSheetKey));
    await tester.pump();

    final route = ModalRoute.of(tester.element(find.byKey(_sheetContentKey)))!;
    expect(route.transitionDuration, const Duration(milliseconds: 420));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 240));

    await tester.pump(const Duration(milliseconds: 42));
    final transition = tester.widget<SlideTransition>(
      find.ancestor(
        of: find.byKey(_sheetContentKey),
        matching: find.byType(SlideTransition),
      ),
    );
    expect(
      transition.position.value,
      offsetMoreOrLessEquals(
        const Offset(0, 0.7452025371513342),
        epsilon: 1e-9,
      ),
    );
  });

  testWidgets('uses the Figma radius, edge inset, and desktop max width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 760);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSheetHost());
    await openSheet(tester);

    final surfaceFinder = find.byType(CLSurface);
    final surface = tester.widget<CLSurface>(surfaceFinder);
    final rect = tester.getRect(surfaceFinder);

    expect(CLThemeData().radii.sheet, 36);
    expect(surface.borderRadius, BorderRadius.circular(36));
    expect(rect.width, 746);
    expect(rect.left, 139);
    expect(rect.right, 885);
    expect(rect.bottom, 750);
  });

  testWidgets('stays inside every safe-area edge', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildSheetHost(
        viewPadding: const EdgeInsets.fromLTRB(24, 47, 12, 34),
        contentHeight: 1000,
      ),
    );
    await openSheet(tester);

    final rect = tester.getRect(find.byType(CLSurface));
    expect(rect.left, 24);
    expect(rect.top, 47);
    expect(rect.right, 388);
    expect(rect.bottom, 766);
  });

  testWidgets('moves above the keyboard inset', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildSheetHost(
        viewPadding: const EdgeInsets.only(bottom: 34),
        viewInsets: const EdgeInsets.only(bottom: 300),
      ),
    );
    await openSheet(tester);

    final rect = tester.getRect(find.byType(CLSurface));
    expect(rect.left, 10);
    expect(rect.right, 390);
    expect(rect.bottom, 500);
  });
}
