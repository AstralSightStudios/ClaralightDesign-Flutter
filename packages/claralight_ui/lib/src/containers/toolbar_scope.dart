import 'package:flutter/widgets.dart';

/// Internal marker used to give toolbar controls their quieter defaults.
class CLToolbarScope extends InheritedWidget {
  const CLToolbarScope({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CLToolbarScope>() != null;

  @override
  bool updateShouldNotify(CLToolbarScope oldWidget) => false;
}
