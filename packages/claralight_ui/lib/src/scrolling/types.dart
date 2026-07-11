/// Axes that a [CLScrollable] or `CLList` can scroll.
enum CLScrollDirection {
  /// Allows free diagonal scrolling in both axes.
  both,

  /// Allows horizontal scrolling only.
  horizontal,

  /// Allows vertical scrolling only.
  vertical,
}

/// Visibility policy for a scrollbar.
enum CLScrollbarVisibility {
  /// Never paints the scrollbar.
  hidden,

  /// Shows the scrollbar while hovered or scrolling, then fades it out.
  auto,

  /// Keeps the scrollbar visible whenever its axis can scroll.
  always,
}
