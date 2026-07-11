import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'edge_effects.dart';
import 'scrollbar_overlay.dart';
import 'types.dart';

bool _isFinite(EdgeInsets value) =>
    value.left.isFinite &&
    value.top.isFinite &&
    value.right.isFinite &&
    value.bottom.isFinite;

/// A Claralight list view with progressive edge blur, masking, and overlay
/// scrollbars - the same visual treatment as [CLScrollable], but backed by a
/// lazily-building [ListView].
///
/// Supports [CLList] (eager children), [CLList.builder] (lazy building), and
/// [CLList.separated] (lazy building with separators). Unless [shrinkWrap] is
/// true, the scroll axis must receive bounded constraints: a vertical list
/// needs a bounded height and a horizontal list needs a bounded width.
class CLList extends StatefulWidget {
  final List<Widget> children;
  final IndexedWidgetBuilder? _itemBuilder;
  final IndexedWidgetBuilder? _separatorBuilder;
  final int? _itemCount;

  /// The axis along which [children] scroll.
  final Axis scrollDirection;

  /// Whether the list reads in the reverse direction.
  final bool reverse;

  /// Optional controller for the scroll axis.
  final ScrollController? controller;

  /// Physics passed through to the underlying [ListView].
  final ScrollPhysics? physics;

  /// Whether the list should shrink-wrap its contents.
  final bool shrinkWrap;

  /// Insets that scroll with the content and contribute to its extent.
  final EdgeInsetsGeometry padding;

  /// Optional fixed extent for every item, passed to [ListView.itemExtent].
  final double? itemExtent;

  /// Optional prototype item, passed to [ListView.prototypeItem].
  final Widget? prototypeItem;

  /// Visibility policy for the scrollbar on the scroll axis.
  final CLScrollbarVisibility scrollbarVisibility;

  /// Physical width of each edge effect after resolving text direction.
  final EdgeInsetsGeometry blurExtent;

  /// Maximum Gaussian sigma contributed by each physical edge.
  final EdgeInsetsGeometry blurSigma;

  /// Circular clip applied to the list and its edge effects.
  final BorderRadius borderRadius;

  /// Cache extent passed through to the underlying [ListView].
  final double? cacheExtent;

  /// Creates a Claralight list view over [children].
  const CLList({
    super.key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.padding = EdgeInsets.zero,
    this.itemExtent,
    this.prototypeItem,
    this.scrollbarVisibility = CLScrollbarVisibility.auto,
    this.blurExtent = const EdgeInsets.all(24),
    this.blurSigma = const EdgeInsets.all(5),
    this.borderRadius = BorderRadius.zero,
    this.cacheExtent,
  }) : _itemBuilder = null,
       _separatorBuilder = null,
       _itemCount = null;

  /// Creates a Claralight list view that builds items lazily.
  const CLList.builder({
    super.key,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.padding = EdgeInsets.zero,
    this.itemExtent,
    this.prototypeItem,
    this.scrollbarVisibility = CLScrollbarVisibility.auto,
    this.blurExtent = const EdgeInsets.all(24),
    this.blurSigma = const EdgeInsets.all(16),
    this.borderRadius = BorderRadius.zero,
    this.cacheExtent,
  }) : children = const <Widget>[],
       _itemBuilder = itemBuilder,
       _separatorBuilder = null,
       _itemCount = itemCount;

  /// Creates a Claralight list view that builds items lazily with separators
  /// between each pair of items.
  const CLList.separated({
    super.key,
    required IndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    required int itemCount,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.padding = EdgeInsets.zero,
    this.scrollbarVisibility = CLScrollbarVisibility.auto,
    this.blurExtent = const EdgeInsets.all(24),
    this.blurSigma = const EdgeInsets.all(16),
    this.borderRadius = BorderRadius.zero,
    this.cacheExtent,
  }) : children = const <Widget>[],
       itemExtent = null,
       prototypeItem = null,
       _itemBuilder = itemBuilder,
       _separatorBuilder = separatorBuilder,
       _itemCount = itemCount;

  @override
  State<CLList> createState() => _CLListState();
}

class _CLListState extends State<CLList> {
  late ScrollController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant CLList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _setController(widget.controller);
    }
  }

  void _setController(ScrollController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final resolvedBlurExtent = widget.blurExtent.resolve(textDirection);
    final resolvedBlurSigma = widget.blurSigma.resolve(textDirection);
    assert(
      resolvedBlurExtent.isNonNegative && _isFinite(resolvedBlurExtent),
      'CLList blurExtent values must be finite and non-negative.',
    );
    assert(
      resolvedBlurSigma.isNonNegative && _isFinite(resolvedBlurSigma),
      'CLList blurSigma values must be finite and non-negative.',
    );

    final isVertical = widget.scrollDirection == Axis.vertical;
    final axisDirection = getAxisDirectionFromAxisReverseAndDirectionality(
      context,
      widget.scrollDirection,
      widget.reverse,
    );

    Widget result = _buildListView();

    result = CLEdgeEffects(
      horizontalController: isVertical ? null : _controller,
      verticalController: isVertical ? _controller : null,
      horizontalAxisDirection: isVertical ? null : axisDirection,
      verticalAxisDirection: isVertical ? axisDirection : null,
      blurExtent: resolvedBlurExtent,
      blurSigma: resolvedBlurSigma,
      borderRadius: widget.borderRadius,
      child: result,
    );

    result = CLScrollbarOverlay(
      horizontalController: isVertical ? null : _controller,
      verticalController: isVertical ? _controller : null,
      horizontalVisibility: isVertical
          ? CLScrollbarVisibility.hidden
          : widget.scrollbarVisibility,
      verticalVisibility: isVertical
          ? widget.scrollbarVisibility
          : CLScrollbarVisibility.hidden,
      thumbColor: CLTheme.of(context).colors.selection,
      child: result,
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: result,
    );
  }

  Widget _buildListView() {
    if (widget._separatorBuilder != null) {
      return ListView.separated(
        key: ValueKey(widget.scrollDirection),
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: _controller,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        itemCount: widget._itemCount!,
        itemBuilder: widget._itemBuilder!,
        separatorBuilder: widget._separatorBuilder!,
        // Keep compatibility with the package's Flutter >=3.30 floor.
        // ignore: deprecated_member_use
        cacheExtent: widget.cacheExtent,
      );
    }
    if (widget._itemBuilder != null) {
      return ListView.builder(
        key: ValueKey(widget.scrollDirection),
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: _controller,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        itemCount: widget._itemCount!,
        itemBuilder: widget._itemBuilder!,
        itemExtent: widget.itemExtent,
        prototypeItem: widget.prototypeItem,
        // Keep compatibility with the package's Flutter >=3.30 floor.
        // ignore: deprecated_member_use
        cacheExtent: widget.cacheExtent,
      );
    }
    return ListView(
      key: ValueKey(widget.scrollDirection),
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: _controller,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      itemExtent: widget.itemExtent,
      prototypeItem: widget.prototypeItem,
      // Keep compatibility with the package's Flutter >=3.30 floor.
      // ignore: deprecated_member_use
      cacheExtent: widget.cacheExtent,
      children: widget.children,
    );
  }
}
