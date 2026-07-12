import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'typography.dart';

export 'colors.dart';
export 'typography.dart';

/// Corner radii of the Claralight shape language.
@immutable
class CLRadii {
  /// Fields, rows, chips, small buttons.
  final double control;

  /// Cards, grouped lists, banners, popovers.
  final double medium;

  /// Panels and sidebars.
  final double panel;

  /// Floating bottom sheets.
  final double sheet;

  /// Modal dialogs.
  final double dialog;

  /// Effectively-round capsules (segmented pills, toolbar buttons).
  final double capsule;

  const CLRadii({
    this.control = 8,
    this.medium = 12,
    this.panel = 18,
    this.sheet = 36,
    this.dialog = 36,
    this.capsule = 999,
  });
}

/// Spacing scale.
@immutable
class CLSpacing {
  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  const CLSpacing({
    this.xs = 4,
    this.s = 8,
    this.m = 12,
    this.l = 16,
    this.xl = 20,
    this.xxl = 24,
  });
}

/// Immutable bundle of every Claralight design token.
@immutable
class CLThemeData {
  final CLColorScheme colors;
  final CLTypography typography;
  final CLRadii radii;
  final CLSpacing spacing;

  CLThemeData({
    CLColorScheme? colors,
    CLTypography? typography,
    this.radii = const CLRadii(),
    this.spacing = const CLSpacing(),
  }) : colors = colors ?? const CLColorScheme.dark(),
       typography = typography ?? CLTypography.standard();

  CLThemeData copyWith({
    CLColorScheme? colors,
    CLTypography? typography,
    CLRadii? radii,
    CLSpacing? spacing,
  }) {
    return CLThemeData(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      radii: radii ?? this.radii,
      spacing: spacing ?? this.spacing,
    );
  }
}

/// Provides a [CLThemeData] to descendant Claralight widgets.
///
/// Widgets work without an ancestor [CLTheme] by falling back to the default
/// dark theme, so drop-in usage inside any app keeps working.
class CLTheme extends InheritedWidget {
  final CLThemeData data;

  const CLTheme({super.key, required this.data, required super.child});

  static CLThemeData? _fallback;

  static CLThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<CLTheme>();
    return theme?.data ?? (_fallback ??= CLThemeData());
  }

  @override
  bool updateShouldNotify(CLTheme oldWidget) => data != oldWidget.data;
}
