import 'package:claralight_ui/claralight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dialogContentKey = Key('dialog-content');

void main() {
  Widget hostWithActions(int actionCount) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CLDialog(
            maxWidth: 400,
            actions: [
              for (var i = 0; i < actionCount; i++)
                SizedBox(key: Key('action-$i'), height: 44),
            ],
            child: const SizedBox(width: 200, height: 40),
          ),
        ),
      ),
    );
  }

  Rect actionRect(WidgetTester tester, int index) {
    return tester.getRect(find.byKey(Key('action-$index')));
  }

  test('defaults to a compact 320px maximum width', () {
    expect(const CLDialog(child: SizedBox()).maxWidth, 320);
  });

  testWidgets('show uses the compact default width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                child: const SizedBox(width: 500, height: 40),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();

    expect(tester.widget<CLDialog>(find.byType(CLDialog)).maxWidth, 320);
    expect(tester.getSize(find.byType(CLDialog)).width, 320);
  });

  testWidgets('route keeps its duration and morphs from trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                triggerRect: const Rect.fromLTWH(20, 20, 100, 40),
                child: const SizedBox(key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();

    final route = ModalRoute.of(tester.element(find.byKey(_dialogContentKey)))!;
    expect(route.transitionDuration, const Duration(milliseconds: 380));
    expect(route.reverseTransitionDuration, CLMotion.standard);

    await tester.pump(const Duration(milliseconds: 380));
    expect(find.byKey(_dialogContentKey), findsOneWidget);
  });

  testWidgets('can be interrupted mid-flight by tapping barrier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CLDialog.show<void>(
                context,
                child: const Text('Dialog body', key: _dialogContentKey),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    // Advance just 50ms into 380ms transition (mid-flight)
    await tester.pump(const Duration(milliseconds: 50));

    // Tap background scrim barrier to interrupt mid-flight
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(_dialogContentKey), findsNothing);
  });

  testWidgets('show accepts triggerContext', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (buttonContext) => TextButton(
              onPressed: () => CLDialog.show<void>(
                buttonContext,
                triggerContext: buttonContext,
                child: const Text('Dialog body'),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));

    expect(find.text('Dialog body'), findsOneWidget);
  });

  testWidgets('lays out two actions horizontally with equal widths', (
    tester,
  ) async {
    await tester.pumpWidget(hostWithActions(2));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);

    expect(first.center.dy, second.center.dy);
    expect(second.left - first.right, 10);
    expect(first.width, second.width);
  });

  testWidgets('stacks three actions vertically at full width', (tester) async {
    await tester.pumpWidget(hostWithActions(3));

    final first = actionRect(tester, 0);
    final second = actionRect(tester, 1);
    final third = actionRect(tester, 2);

    expect(first.center.dx, second.center.dx);
    expect(second.center.dx, third.center.dx);
    expect(second.top - first.bottom, 10);
    expect(third.top - second.bottom, 10);
    expect(first.width, second.width);
    expect(second.width, third.width);
  });
}
