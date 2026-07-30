import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../lists/list_tile.dart';
import '../menus/menu.dart';
import '../theme/theme.dart';
import 'toolbar.dart';

/// Controls whether a toolbar item may move into the overflow menu.
enum CLToolbarItemRetention {
  /// The item always remains on the toolbar.
  pinned,

  /// The item may move into the overflow menu when space is tight.
  overflowable,
}

/// Builds the toolbar representation of an overflow-toolbar item.
typedef CLOverflowToolbarItemBuilder = Widget Function(BuildContext context);

/// Builds the menu representation of an overflow-toolbar item.
///
/// Call [closeMenu] after handling the action when the row should dismiss the
/// overflow menu. Rows may also keep the menu open for multi-action workflows.
typedef CLOverflowToolbarOverflowBuilder =
    Widget Function(BuildContext context, VoidCallback closeMenu);

/// Builds the overflow trigger.
///
/// [toggle] is null when [CLOverflowToolbar.overflowEnabled] is false.
typedef CLOverflowToolbarTriggerBuilder =
    Widget Function(BuildContext context, VoidCallback? toggle);

/// Builds the toolbar shell around [visibleChildren].
///
/// The list keeps the visible items' logical order. When a hidden selected
/// item is promoted, it occupies the final tool slot. The overflow trigger,
/// when present, remains the final child. The shell must use the toolbar's
/// declared [CLOverflowToolbar.spacing] and
/// [CLOverflowToolbar.horizontalPadding], because those values are the width
/// allocation contract.
typedef CLOverflowToolbarBuilder =
    Widget Function(BuildContext context, List<Widget> visibleChildren);

class _CLOverflowToolbarTriggerKey extends LocalKey {
  const _CLOverflowToolbarTriggerKey();
}

typedef _CLOverflowToolbarShellBuilder<T> =
    Widget Function(
      BuildContext context,
      List<Widget> children,
      _CLOverflowToolbarAllocation<T> allocation,
    );

typedef _CLOverflowActiveTriggerBuilder<T> =
    Widget Function(
      BuildContext context,
      _CLOverflowToolbarAllocation<T> allocation,
    );

/// A fixed-width item understood by [CLOverflowToolbar].
///
/// [extent] is the item's main-axis width, not a value measured from the
/// widget returned by [toolbarBuilder]. It is deliberately explicit so the
/// overflow decision can happen before hidden toolbar widgets are built.
class CLOverflowToolbarItem<T> {
  /// Creates an item with a stable [id] and an explicit toolbar [extent].
  const CLOverflowToolbarItem({
    required this.id,
    required this.extent,
    required this.retention,
    required this.toolbarBuilder,
    this.overflowPriority = 0,
    this.overflowLabel,
    this.overflowLeadingExtent = 0,
    this.overflowBuilder,
  }) : assert(
         extent > 0 && extent < double.infinity,
         'CLOverflowToolbarItem.extent must be finite and greater than zero.',
       ),
       assert(
         overflowLeadingExtent >= 0 && overflowLeadingExtent < double.infinity,
         'CLOverflowToolbarItem.overflowLeadingExtent must be finite and '
         'non-negative.',
       ),
       assert(
         retention == CLToolbarItemRetention.pinned ||
             (overflowBuilder != null &&
                 overflowLabel != null &&
                 overflowLabel != ''),
         'Overflowable toolbar items require an overflowLabel and '
         'overflowBuilder.',
       );

  /// Stable identity used for keys, hidden-ID reporting, and duplicate checks.
  final T id;

  /// Main-axis width reserved by the toolbar representation.
  final double extent;

  /// Whether this item is always visible or may enter the menu.
  final CLToolbarItemRetention retention;

  /// Lower priorities are moved to the menu first.
  final int overflowPriority;

  /// Builds the toolbar representation when this item is visible.
  final CLOverflowToolbarItemBuilder toolbarBuilder;

  /// Single-line label used to size this item's overflow-menu row.
  ///
  /// Required for overflowable items. The row built by [overflowBuilder]
  /// should render the same label with the standard [CLListTile] callout style.
  final String? overflowLabel;

  /// Width before [overflowLabel] inside the menu row, including its gap.
  ///
  /// For a medium [CLListTile] with a leading icon, use `28` (18px icon plus
  /// the 10px label gap).
  final double overflowLeadingExtent;

  /// Builds the menu row when this overflowable item is hidden.
  final CLOverflowToolbarOverflowBuilder? overflowBuilder;
}

/// A [CLToolbar] that moves low-priority tools into a [CLMenu] as space gets
/// tight.
///
/// Visibility is calculated from the explicit extents in [items] before any
/// toolbar builders are called. This avoids a one-frame flex overflow and,
/// importantly, avoids creating hidden focus, hit-test, and semantics nodes.
/// The default shell is [CLToolbar]; use [toolbarBuilder] when the visible
/// children need a different shell. The shell receives logical-order items,
/// except that a promoted selected item occupies the final slot before More.
class CLOverflowToolbar<T> extends StatefulWidget {
  /// Creates an overflow-aware toolbar.
  CLOverflowToolbar({
    super.key,
    required this.items,
    required this.overflowTriggerBuilder,
    this.toolbarBuilder,
    this.spacing = 2,
    this.horizontalPadding = 3,
    this.overflowExtent = 44,
    this.overflowEnabled = true,
    this.selectedId,
    this.menuPadding = const EdgeInsets.all(10),
    this.onOverflowChanged,
  }) : assert(
         _haveUniqueIds(items),
         'CLOverflowToolbar item IDs must be unique.',
       ),
       assert(
         _haveRequiredOverflowBuilders(items),
         'Overflowable CLOverflowToolbar items require an overflowLabel and '
         'overflowBuilder.',
       ),
       assert(
         spacing >= 0 && spacing < double.infinity,
         'CLOverflowToolbar.spacing must be finite and non-negative.',
       ),
       assert(
         horizontalPadding >= 0 && horizontalPadding < double.infinity,
         'CLOverflowToolbar.horizontalPadding must be finite and non-negative.',
       ),
       assert(
         overflowExtent > 0 && overflowExtent < double.infinity,
         'CLOverflowToolbar.overflowExtent must be finite and greater than zero.',
       );

  /// Items in logical order. The menu always retains this order; a selected
  /// item promoted from the menu moves to the toolbar's final tool slot.
  final List<CLOverflowToolbarItem<T>> items;

  /// Builds the More/overflow trigger when at least one item is hidden.
  final CLOverflowToolbarTriggerBuilder overflowTriggerBuilder;

  /// Builds the toolbar shell. Defaults to [CLToolbar]. Custom shells must
  /// render the supplied children with exactly [spacing] between them and
  /// [horizontalPadding] on both outer edges.
  final CLOverflowToolbarBuilder? toolbarBuilder;

  /// Gap between toolbar children used for allocation and by the default
  /// [CLToolbar] shell.
  final double spacing;

  /// Outer inset on each horizontal edge used for allocation and by the
  /// default [CLToolbar] shell.
  final double horizontalPadding;

  /// Width reserved for the overflow trigger when it is present.
  final double overflowExtent;

  /// Whether the More trigger accepts pointer or keyboard activation.
  ///
  /// [overflowTriggerBuilder] receives a null toggle while disabled so its
  /// visual and semantic state can share this same source of truth.
  final bool overflowEnabled;

  /// The controlled selected item.
  ///
  /// When this item would otherwise be hidden, it replaces the trailing
  /// visible overflowable item and is placed immediately before More.
  final T? selectedId;

  /// Insets around the expanded menu rows.
  final EdgeInsetsGeometry menuPadding;

  /// Reports the hidden IDs after the calculated allocation changes.
  ///
  /// The set is immutable. An initial report is sent after the first frame,
  /// including an empty set when every item fits.
  final ValueChanged<Set<T>>? onOverflowChanged;

  @override
  State<CLOverflowToolbar<T>> createState() => _CLOverflowToolbarState<T>();
}

class _CLOverflowToolbarState<T> extends State<CLOverflowToolbar<T>> {
  static const _menuRowHorizontalPadding = 16.0;
  static const _menuScreenMargin = 12.0;

  CLMenuController _menuController = CLMenuController();
  final _retiredMenus = <CLMenuController>[];
  _CLOverflowToolbarAllocation<T>? _lastAllocation;
  Set<T>? _lastReportedHiddenIds;
  Set<T>? _pendingHiddenIds;
  bool _overflowReportScheduled = false;

  @override
  void didUpdateWidget(CLOverflowToolbar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overflowEnabled &&
        !widget.overflowEnabled &&
        _menuController.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.overflowEnabled) _menuController.close();
      });
    }
  }

  @override
  void dispose() {
    _menuController.close();
    _menuController.dispose();
    for (final retiredMenu in _retiredMenus) {
      retiredMenu.close();
      retiredMenu.dispose();
    }
    _retiredMenus.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWasOpen = _menuController.isOpen;
        final allocation = _allocate(context, constraints.maxWidth);
        _recordAllocation(allocation);

        return _CLOverflowMigrationSurface<T>(
          allocation: allocation,
          items: widget.items,
          textDirection: Directionality.of(context),
          spacing: widget.spacing,
          horizontalPadding: widget.horizontalPadding,
          overflowExtent: widget.overflowExtent,
          overflowEnabled: widget.overflowEnabled,
          menuWidth: allocation.menuWidth,
          menuPadding: widget.menuPadding,
          usesCustomShell: widget.toolbarBuilder != null,
          animate: !MediaQuery.disableAnimationsOf(context) && !menuWasOpen,
          shellBuilder: _buildToolbarShell,
          activeTriggerBuilder: _buildOverflowMenu,
          visualTriggerBuilder: widget.overflowTriggerBuilder,
        );
      },
    );
  }

  Widget _buildToolbarShell(
    BuildContext context,
    List<Widget> toolbarChildren,
    _CLOverflowToolbarAllocation<T> allocation,
  ) {
    final toolbar =
        widget.toolbarBuilder?.call(
          context,
          List<Widget>.unmodifiable(toolbarChildren),
        ) ??
        CLToolbar(
          spacing: widget.spacing,
          padding: widget.horizontalPadding,
          children: toolbarChildren,
        );

    if (!allocation.useHorizontalScroll) return toolbar;

    // Pinned items must remain present even when their minimum allocation is
    // wider than the viewport.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: allocation.toolbarWidth, child: toolbar),
    );
  }

  Widget _buildOverflowMenu(
    BuildContext context,
    _CLOverflowToolbarAllocation<T> allocation,
  ) {
    final menuChildren = <Widget>[];
    for (final index in allocation.hiddenIndices) {
      final item = widget.items[index];
      menuChildren.add(
        KeyedSubtree(
          key: ValueKey<T>(item.id),
          child: item.overflowBuilder!(context, _menuController.close),
        ),
      );
    }

    return CLMenu(
      anchor: const SizedBox.shrink(),
      controller: _menuController,
      buttonSize: widget.overflowExtent,
      menuWidth: allocation.menuWidth,
      padding: widget.menuPadding,
      buttonBuilder: (context, toggle) {
        final enabledToggle = widget.overflowEnabled ? toggle : null;
        return FocusableActionDetector(
          enabled: widget.overflowEnabled,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                enabledToggle?.call();
                return null;
              },
            ),
          },
          child: SizedBox(
            width: widget.overflowExtent,
            child: Align(
              alignment: Alignment.center,
              child: widget.overflowTriggerBuilder(context, enabledToggle),
            ),
          ),
        );
      },
      children: menuChildren,
    );
  }

  _CLOverflowToolbarAllocation<T> _allocate(
    BuildContext context,
    double maxWidth,
  ) {
    final allIndices = [
      for (var index = 0; index < widget.items.length; index++) index,
    ];
    final naturalWidth = _widthFor(allIndices, includeOverflow: false);

    if (!maxWidth.isFinite || naturalWidth <= maxWidth) {
      return _makeAllocation(
        context: context,
        visibleIndices: allIndices,
        hiddenIndices: const [],
        maxWidth: maxWidth,
        naturalWidth: naturalWidth,
        hasOverflow: false,
        useHorizontalScroll: false,
      );
    }

    final removable = allIndices
        .where(
          (index) =>
              widget.items[index].retention ==
              CLToolbarItemRetention.overflowable,
        )
        .toList();
    removable.sort((a, b) {
      final priority = widget.items[a].overflowPriority.compareTo(
        widget.items[b].overflowPriority,
      );
      if (priority != 0) return priority;
      // Later logical items are trailing items and leave first on a tie.
      return b.compareTo(a);
    });

    if (removable.isEmpty) {
      return _makeAllocation(
        context: context,
        visibleIndices: allIndices,
        hiddenIndices: const [],
        maxWidth: maxWidth,
        naturalWidth: naturalWidth,
        hasOverflow: false,
        useHorizontalScroll: naturalWidth > maxWidth,
      );
    }

    final hiddenIndices = <int>{};
    for (final index in removable) {
      hiddenIndices.add(index);
      final visibleIndices = [
        for (final candidate in allIndices)
          if (!hiddenIndices.contains(candidate)) candidate,
      ];
      final toolbarWidth = _widthFor(visibleIndices, includeOverflow: true);
      if (toolbarWidth <= maxWidth) {
        return _makeAllocation(
          context: context,
          visibleIndices: visibleIndices,
          hiddenIndices: hiddenIndices,
          maxWidth: maxWidth,
          naturalWidth: naturalWidth,
          hasOverflow: true,
          useHorizontalScroll: false,
        );
      }
    }

    final pinnedIndices = [
      for (final index in allIndices)
        if (widget.items[index].retention == CLToolbarItemRetention.pinned)
          index,
    ];
    return _makeAllocation(
      context: context,
      visibleIndices: pinnedIndices,
      hiddenIndices: hiddenIndices,
      maxWidth: maxWidth,
      naturalWidth: naturalWidth,
      hasOverflow: true,
      useHorizontalScroll: true,
    );
  }

  _CLOverflowToolbarAllocation<T> _makeAllocation({
    required BuildContext context,
    required List<int> visibleIndices,
    required Iterable<int> hiddenIndices,
    required double maxWidth,
    required double naturalWidth,
    required bool hasOverflow,
    required bool useHorizontalScroll,
  }) {
    final resolvedVisibleIndices = List<int>.of(visibleIndices);
    final resolvedHiddenIndices = hiddenIndices.toSet();
    var resolvedUseHorizontalScroll = useHorizontalScroll;
    final selectedId = widget.selectedId;
    final selectedIndex = selectedId == null
        ? -1
        : widget.items.indexWhere((item) => item.id == selectedId);

    if (selectedIndex >= 0 && resolvedHiddenIndices.remove(selectedIndex)) {
      final replacementPosition = resolvedVisibleIndices.lastIndexWhere(
        (index) =>
            widget.items[index].retention ==
            CLToolbarItemRetention.overflowable,
      );
      if (replacementPosition >= 0) {
        resolvedHiddenIndices.add(
          resolvedVisibleIndices.removeAt(replacementPosition),
        );
      }
      resolvedVisibleIndices.add(selectedIndex);

      while (maxWidth.isFinite &&
          _widthFor(
                resolvedVisibleIndices,
                includeOverflow: resolvedHiddenIndices.isNotEmpty,
              ) >
              maxWidth) {
        final extraPosition = resolvedVisibleIndices.lastIndexWhere(
          (index) =>
              index != selectedIndex &&
              widget.items[index].retention ==
                  CLToolbarItemRetention.overflowable,
        );
        if (extraPosition < 0) {
          resolvedUseHorizontalScroll = true;
          break;
        }
        resolvedHiddenIndices.add(
          resolvedVisibleIndices.removeAt(extraPosition),
        );
      }
    }

    final resolvedHasOverflow = hasOverflow && resolvedHiddenIndices.isNotEmpty;
    final hiddenIndexList = [
      for (var index = 0; index < widget.items.length; index++)
        if (resolvedHiddenIndices.contains(index)) index,
    ];
    final hiddenIds = <T>{
      for (final index in hiddenIndexList) widget.items[index].id,
    };
    final toolbarWidth = _widthFor(
      resolvedVisibleIndices,
      includeOverflow: resolvedHasOverflow,
    );
    if (maxWidth.isFinite && toolbarWidth > maxWidth) {
      resolvedUseHorizontalScroll = true;
    }
    return _CLOverflowToolbarAllocation<T>(
      visibleIndices: List<int>.unmodifiable(resolvedVisibleIndices),
      hiddenIndices: List<int>.unmodifiable(hiddenIndexList),
      hiddenIds: Set<T>.unmodifiable(hiddenIds),
      itemIds: List<T>.unmodifiable(widget.items.map((item) => item.id)),
      maxWidth: maxWidth,
      naturalWidth: naturalWidth,
      toolbarWidth: toolbarWidth,
      hasOverflow: resolvedHasOverflow,
      useHorizontalScroll: resolvedUseHorizontalScroll,
      overflowExtent: widget.overflowExtent,
      spacing: widget.spacing,
      horizontalPadding: widget.horizontalPadding,
      menuWidth: _menuWidth(context, hiddenIndexList),
      menuPadding: widget.menuPadding,
    );
  }

  double _menuWidth(BuildContext context, List<int> hiddenIndices) {
    final textDirection = Directionality.of(context);
    final mediaQuery = MediaQuery.maybeOf(context);
    final style = CLTheme.of(
      context,
    ).typography.callout.withCLWeight(FontWeight.w400);
    var widestRow = 0.0;

    for (final index in hiddenIndices) {
      final item = widget.items[index];
      final painter = TextPainter(
        text: TextSpan(text: item.overflowLabel!, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: mediaQuery?.textScaler ?? TextScaler.noScaling,
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      widestRow = math.max(
        widestRow,
        painter.width + item.overflowLeadingExtent,
      );
    }

    final naturalWidth =
        widestRow +
        _menuRowHorizontalPadding +
        widget.menuPadding.resolve(textDirection).horizontal;
    final availableWidth = mediaQuery == null
        ? double.infinity
        : math.max(
            widget.overflowExtent,
            mediaQuery.size.width -
                mediaQuery.padding.horizontal -
                _menuScreenMargin * 2,
          );
    return math.max(
      widget.overflowExtent,
      math.min(naturalWidth, availableWidth),
    );
  }

  double _widthFor(List<int> indices, {required bool includeOverflow}) {
    final childCount = indices.length + (includeOverflow ? 1 : 0);
    if (childCount == 0) return widget.horizontalPadding * 2;

    var width = widget.horizontalPadding * 2;
    for (final index in indices) {
      width += widget.items[index].extent;
    }
    if (includeOverflow) width += widget.overflowExtent;
    width += widget.spacing * (childCount - 1);
    return width;
  }

  void _recordAllocation(_CLOverflowToolbarAllocation<T> allocation) {
    final previous = _lastAllocation;
    _lastAllocation = allocation;

    if (previous != null && !previous.isEquivalentTo(allocation)) {
      if (_menuController.isOpen) {
        // Closing before the new menu children are mounted prevents CLMenu
        // from restoring focus into an allocation that no longer exists.
        _menuController.close();
      }
      if (previous.hasOverflow &&
          (!allocation.hasOverflow ||
              previous.useHorizontalScroll != allocation.useHorizontalScroll)) {
        final retiredMenu = _menuController;
        _retiredMenus.add(retiredMenu);
        _menuController = CLMenuController();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_retiredMenus.remove(retiredMenu)) {
            retiredMenu.dispose();
          }
        });
      }
    }

    final callback = widget.onOverflowChanged;
    if (callback == null ||
        (_lastReportedHiddenIds != null &&
            _sameSet(_lastReportedHiddenIds!, allocation.hiddenIds))) {
      return;
    }
    _lastReportedHiddenIds = allocation.hiddenIds;
    _pendingHiddenIds = allocation.hiddenIds;
    if (_overflowReportScheduled) return;
    _overflowReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overflowReportScheduled = false;
      final hiddenIds = _pendingHiddenIds;
      _pendingHiddenIds = null;
      if (!mounted || hiddenIds == null) return;
      widget.onOverflowChanged?.call(hiddenIds);
    });
  }
}

class _CLOverflowMigrationSurface<T> extends StatefulWidget {
  const _CLOverflowMigrationSurface({
    required this.allocation,
    required this.items,
    required this.textDirection,
    required this.spacing,
    required this.horizontalPadding,
    required this.overflowExtent,
    required this.overflowEnabled,
    required this.menuWidth,
    required this.menuPadding,
    required this.usesCustomShell,
    required this.animate,
    required this.shellBuilder,
    required this.activeTriggerBuilder,
    required this.visualTriggerBuilder,
  });

  final _CLOverflowToolbarAllocation<T> allocation;
  final List<CLOverflowToolbarItem<T>> items;
  final TextDirection textDirection;
  final double spacing;
  final double horizontalPadding;
  final double overflowExtent;
  final bool overflowEnabled;
  final double menuWidth;
  final EdgeInsetsGeometry menuPadding;
  final bool usesCustomShell;
  final bool animate;
  final _CLOverflowToolbarShellBuilder<T> shellBuilder;
  final _CLOverflowActiveTriggerBuilder<T> activeTriggerBuilder;
  final CLOverflowToolbarTriggerBuilder visualTriggerBuilder;

  @override
  State<_CLOverflowMigrationSurface<T>> createState() =>
      _CLOverflowMigrationSurfaceState<T>();
}

class _CLOverflowMigrationSurfaceState<T>
    extends State<_CLOverflowMigrationSurface<T>>
    with SingleTickerProviderStateMixin {
  static const _migrationDuration = CLMotion.standard;
  static const _migrationCurve = CLMotion.easeOut;
  static const _collapsedScaleX = 0.8;

  late final AnimationController _migration;
  Map<LocalKey, _CLOverflowVisualState> _from = const {};
  Map<LocalKey, _CLOverflowVisualState> _to = const {};
  _CLOverflowToolbarAllocation<T>? _settledAllocation;

  @override
  void initState() {
    super.initState();
    _migration = AnimationController(
      vsync: this,
      duration: _migrationDuration,
      value: 1,
    )..addStatusListener(_handleMigrationStatus);
    _commitImmediately(widget.allocation);
  }

  @override
  void didUpdateWidget(_CLOverflowMigrationSurface<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.animate ||
        !_sameVisualConfiguration(oldWidget, widget) ||
        oldWidget.allocation.useHorizontalScroll ||
        widget.allocation.useHorizontalScroll) {
      _commitImmediately(widget.allocation);
      return;
    }

    if (_sameVisualDistribution(oldWidget.allocation, widget.allocation)) {
      if (_settledAllocation != null) {
        _settledAllocation = widget.allocation;
      }
      return;
    }

    _retarget(oldWidget.allocation, widget.allocation);
  }

  void _commitImmediately(_CLOverflowToolbarAllocation<T> allocation) {
    _migration.stop();
    final visuals = _targetVisuals(allocation);
    _from = visuals;
    _to = visuals;
    _settledAllocation = allocation;
    _migration.value = 1;
  }

  Map<LocalKey, _CLOverflowVisualState> _targetVisuals(
    _CLOverflowToolbarAllocation<T> allocation,
  ) {
    final starts = _logicalStarts(allocation);
    return <LocalKey, _CLOverflowVisualState>{
      for (final entry in starts.entries)
        entry.key: _CLOverflowVisualState(
          start: entry.value,
          opacity: 1,
          scaleX: 1,
        ),
    };
  }

  Map<LocalKey, _CLOverflowVisualState> _currentVisuals() {
    return <LocalKey, _CLOverflowVisualState>{
      for (final key in {..._from.keys, ..._to.keys})
        key: _CLOverflowVisualState.lerp(
          _from[key]!,
          _to[key]!,
          _migration.value,
        ),
    };
  }

  void _retarget(
    _CLOverflowToolbarAllocation<T> currentAllocation,
    _CLOverflowToolbarAllocation<T> targetAllocation,
  ) {
    final allowedKeys = <LocalKey>{
      ..._allocationKeys(currentAllocation),
      ..._allocationKeys(targetAllocation),
    };
    final current = _currentVisuals()
      ..removeWhere((key, _) => !allowedKeys.contains(key));
    final currentStarts = _logicalStarts(currentAllocation);
    final targetStarts = _logicalStarts(targetAllocation);
    final nextFrom = <LocalKey, _CLOverflowVisualState>{};
    final nextTo = <LocalKey, _CLOverflowVisualState>{};
    final oldMoreStart = currentStarts[const _CLOverflowToolbarTriggerKey()];
    final newMoreStart = targetStarts[const _CLOverflowToolbarTriggerKey()];

    for (final entry in targetStarts.entries) {
      final key = entry.key;
      final currentVisual = current[key];
      nextFrom[key] =
          currentVisual ??
          _CLOverflowVisualState(
            start: key is _CLOverflowToolbarTriggerKey
                ? entry.value
                : oldMoreStart ?? entry.value,
            opacity: 0,
            scaleX: _collapsedScaleX,
          );
      nextTo[key] = _CLOverflowVisualState(
        start: entry.value,
        opacity: 1,
        scaleX: 1,
      );
    }

    for (final entry in current.entries) {
      if (targetStarts.containsKey(entry.key)) continue;
      nextFrom[entry.key] = entry.value;
      nextTo[entry.key] = _CLOverflowVisualState(
        start: entry.key is _CLOverflowToolbarTriggerKey
            ? entry.value.start
            : newMoreStart ?? entry.value.start,
        opacity: 0,
        scaleX: _collapsedScaleX,
      );
    }

    _migration.stop();
    _from = Map<LocalKey, _CLOverflowVisualState>.unmodifiable(nextFrom);
    _to = Map<LocalKey, _CLOverflowVisualState>.unmodifiable(nextTo);
    _settledAllocation = null;
    _migration.value = 0;
    _migration.animateTo(
      1,
      duration: _migrationDuration,
      curve: _migrationCurve,
    );
  }

  Set<LocalKey> _allocationKeys(_CLOverflowToolbarAllocation<T> allocation) {
    return <LocalKey>{
      for (final index in allocation.visibleIndices)
        ValueKey<T>(widget.items[index].id),
      if (allocation.hasOverflow) const _CLOverflowToolbarTriggerKey(),
    };
  }

  Map<LocalKey, double> _logicalStarts(
    _CLOverflowToolbarAllocation<T> allocation,
  ) {
    final starts = <LocalKey, double>{};
    var start = widget.horizontalPadding;
    for (final index in allocation.visibleIndices) {
      starts[ValueKey<T>(widget.items[index].id)] = start;
      start += widget.items[index].extent + widget.spacing;
    }
    if (allocation.hasOverflow) {
      starts[const _CLOverflowToolbarTriggerKey()] = start;
    }
    return starts;
  }

  void _handleMigrationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _settledAllocation == null) {
      _commitImmediately(widget.allocation);
    }
  }

  @override
  void dispose() {
    _migration.removeStatusListener(_handleMigrationStatus);
    _migration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _migration,
      builder: (context, _) {
        final visuals = <LocalKey, _CLOverflowVisualState>{
          for (final key in {..._from.keys, ..._to.keys})
            key: _CLOverflowVisualState.lerp(
              _from[key]!,
              _to[key]!,
              _migration.value,
            ),
        };
        return _buildMigrationStack(context, visuals);
      },
    );
  }

  Widget _buildMigrationStack(
    BuildContext context,
    Map<LocalKey, _CLOverflowVisualState> visuals,
  ) {
    final targetStarts = _logicalStarts(widget.allocation);
    final toolbarChildren = <Widget>[];
    for (final index in widget.allocation.visibleIndices) {
      final item = widget.items[index];
      final key = ValueKey<T>(item.id);
      toolbarChildren.add(
        KeyedSubtree(
          key: key,
          child: SizedBox(
            width: item.extent,
            child: _buildActiveVisual(
              visual: visuals[key]!,
              targetStart: targetStarts[key]!,
              child: item.toolbarBuilder(context),
            ),
          ),
        ),
      );
    }
    if (widget.allocation.hasOverflow) {
      const key = _CLOverflowToolbarTriggerKey();
      toolbarChildren.add(
        KeyedSubtree(
          key: key,
          child: _buildActiveVisual(
            visual: visuals[key]!,
            targetStart: targetStarts[key]!,
            child: widget.activeTriggerBuilder(context, widget.allocation),
          ),
        ),
      );
    }

    final activeToolbar = widget.shellBuilder(
      context,
      toolbarChildren,
      widget.allocation,
    );
    final outgoing = <Widget>[];
    for (final entry in visuals.entries) {
      if (targetStarts.containsKey(entry.key) || _migration.value >= 1) {
        continue;
      }
      outgoing.add(_buildOutgoingVisual(context, entry.key, entry.value));
    }
    return ClipRect(child: Stack(children: [activeToolbar, ...outgoing]));
  }

  Widget _buildActiveVisual({
    required _CLOverflowVisualState visual,
    required double targetStart,
    required Widget child,
  }) {
    final physicalStartDelta =
        (visual.start - targetStart) *
        (widget.textDirection == TextDirection.rtl ? -1 : 1);
    final inert = visual.opacity <= 0.001;
    return IgnorePointer(
      ignoring: inert,
      child: ExcludeFocus(
        excluding: inert,
        child: ExcludeSemantics(
          excluding: inert,
          child: Opacity(
            opacity: visual.opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(physicalStartDelta, 0),
              transformHitTests: true,
              child: Transform(
                alignment: AlignmentDirectional.center,
                transform: Matrix4.diagonal3Values(visual.scaleX, 1, 1),
                transformHitTests: true,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingVisual(
    BuildContext context,
    LocalKey key,
    _CLOverflowVisualState visual,
  ) {
    final itemIndex = _itemIndexForKey(key);
    final extent = itemIndex == null
        ? widget.overflowExtent
        : widget.items[itemIndex].extent;
    final representation = itemIndex == null
        ? SizedBox(
            width: widget.overflowExtent,
            child: Align(
              alignment: Alignment.center,
              child: widget.visualTriggerBuilder(
                context,
                widget.overflowEnabled ? _noop : null,
              ),
            ),
          )
        : widget.items[itemIndex].toolbarBuilder(context);

    return PositionedDirectional(
      key: key,
      start: visual.start,
      width: extent,
      top: 0,
      bottom: 0,
      child: ExcludeFocus(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: visual.opacity.clamp(0.0, 1.0),
              child: Transform(
                alignment: AlignmentDirectional.center,
                transform: Matrix4.diagonal3Values(visual.scaleX, 1, 1),
                transformHitTests: true,
                child: representation,
              ),
            ),
          ),
        ),
      ),
    );
  }

  int? _itemIndexForKey(LocalKey key) {
    for (var index = 0; index < widget.items.length; index++) {
      if (key == ValueKey<T>(widget.items[index].id)) return index;
    }
    return null;
  }
}

class _CLOverflowVisualState {
  const _CLOverflowVisualState({
    required this.start,
    required this.opacity,
    required this.scaleX,
  });

  final double start;
  final double opacity;
  final double scaleX;

  static _CLOverflowVisualState lerp(
    _CLOverflowVisualState from,
    _CLOverflowVisualState to,
    double t,
  ) {
    return _CLOverflowVisualState(
      start: from.start + (to.start - from.start) * t,
      opacity: from.opacity + (to.opacity - from.opacity) * t,
      scaleX: from.scaleX + (to.scaleX - from.scaleX) * t,
    );
  }
}

bool _sameVisualConfiguration<T>(
  _CLOverflowMigrationSurface<T> first,
  _CLOverflowMigrationSurface<T> second,
) {
  if (first.textDirection != second.textDirection ||
      first.spacing != second.spacing ||
      first.horizontalPadding != second.horizontalPadding ||
      first.overflowExtent != second.overflowExtent ||
      first.overflowEnabled != second.overflowEnabled ||
      first.menuPadding != second.menuPadding ||
      first.usesCustomShell != second.usesCustomShell ||
      first.items.length != second.items.length) {
    return false;
  }
  for (var index = 0; index < first.items.length; index++) {
    final firstItem = first.items[index];
    final secondItem = second.items[index];
    if (firstItem.id != secondItem.id ||
        firstItem.extent != secondItem.extent ||
        firstItem.overflowPriority != secondItem.overflowPriority ||
        firstItem.retention != secondItem.retention) {
      return false;
    }
  }
  return true;
}

bool _sameVisualDistribution<T>(
  _CLOverflowToolbarAllocation<T> first,
  _CLOverflowToolbarAllocation<T> second,
) {
  return _sameList(first.visibleIndices, second.visibleIndices) &&
      _sameList(first.hiddenIndices, second.hiddenIndices) &&
      _sameList(first.itemIds, second.itemIds) &&
      first.hasOverflow == second.hasOverflow &&
      first.useHorizontalScroll == second.useHorizontalScroll;
}

void _noop() {}

class _CLOverflowToolbarAllocation<T> {
  const _CLOverflowToolbarAllocation({
    required this.visibleIndices,
    required this.hiddenIndices,
    required this.hiddenIds,
    required this.itemIds,
    required this.maxWidth,
    required this.naturalWidth,
    required this.toolbarWidth,
    required this.hasOverflow,
    required this.useHorizontalScroll,
    required this.overflowExtent,
    required this.spacing,
    required this.horizontalPadding,
    required this.menuWidth,
    required this.menuPadding,
  });

  final List<int> visibleIndices;
  final List<int> hiddenIndices;
  final Set<T> hiddenIds;
  final List<T> itemIds;
  final double maxWidth;
  final double naturalWidth;
  final double toolbarWidth;
  final bool hasOverflow;
  final bool useHorizontalScroll;
  final double overflowExtent;
  final double spacing;
  final double horizontalPadding;
  final double menuWidth;
  final EdgeInsetsGeometry menuPadding;

  bool isEquivalentTo(_CLOverflowToolbarAllocation<T> other) {
    return _sameList(visibleIndices, other.visibleIndices) &&
        _sameList(hiddenIndices, other.hiddenIndices) &&
        _sameSet(hiddenIds, other.hiddenIds) &&
        _sameList(itemIds, other.itemIds) &&
        maxWidth == other.maxWidth &&
        naturalWidth == other.naturalWidth &&
        toolbarWidth == other.toolbarWidth &&
        hasOverflow == other.hasOverflow &&
        useHorizontalScroll == other.useHorizontalScroll &&
        overflowExtent == other.overflowExtent &&
        spacing == other.spacing &&
        horizontalPadding == other.horizontalPadding &&
        menuWidth == other.menuWidth &&
        menuPadding == other.menuPadding;
  }
}

bool _haveUniqueIds<T>(List<CLOverflowToolbarItem<T>> items) {
  final ids = <T>{};
  for (final item in items) {
    if (!ids.add(item.id)) return false;
  }
  return true;
}

bool _haveRequiredOverflowBuilders<T>(List<CLOverflowToolbarItem<T>> items) {
  for (final item in items) {
    if (item.retention == CLToolbarItemRetention.overflowable &&
        (item.overflowBuilder == null ||
            item.overflowLabel == null ||
            item.overflowLabel == '')) {
      return false;
    }
  }
  return true;
}

bool _sameSet<T>(Set<T> first, Set<T> second) {
  if (first.length != second.length) return false;
  return first.containsAll(second);
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
