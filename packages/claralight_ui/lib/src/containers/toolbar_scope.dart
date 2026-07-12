import 'package:flutter/widgets.dart';

import '../foundation/control_size.dart';

/// Internal marker used to configure controls inside a toolbar.
class CLToolbarScope extends InheritedWidget {
  final CLControlSize size;

  const CLToolbarScope({super.key, required this.size, required super.child});

  static CLToolbarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CLToolbarScope>();

  static bool contains(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(CLToolbarScope oldWidget) => size != oldWidget.size;
}
