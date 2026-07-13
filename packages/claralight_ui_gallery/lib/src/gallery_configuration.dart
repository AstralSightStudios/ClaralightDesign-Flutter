part of '../main.dart';

/// Initial scroll offset for hands-free screenshot verification, e.g.
/// --dart-define=GALLERY_SCROLL=2200.
const double kInitialScroll =
    // ignore: avoid_double_and_int_checks
    1.0 * int.fromEnvironment('GALLERY_SCROLL');

/// Auto-opens a popup demo after launch for hands-free screenshots:
/// --dart-define=AUTO_OPEN=dialog|sheet|menu|popover.
const String kAutoOpen = String.fromEnvironment('AUTO_OPEN');
