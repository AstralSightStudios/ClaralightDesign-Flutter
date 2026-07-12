/// Density steps shared by Claralight controls.
///
/// `small` matches the desktop inspector density of the design mockups,
/// `medium` the toolbar density, `large` the touch density of the iOS
/// mockups.
enum CLControlSize {
  small,
  medium,
  large;

  /// Standard height for controls at this density step.
  double get controlHeight => switch (this) {
    CLControlSize.small => 28,
    CLControlSize.medium => 36,
    CLControlSize.large => 44,
  };
}
