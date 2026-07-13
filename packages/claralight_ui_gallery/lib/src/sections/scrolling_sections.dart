part of '../../main.dart';

class _ScrollableSection extends StatefulWidget {
  const _ScrollableSection();

  @override
  State<_ScrollableSection> createState() => _ScrollableSectionState();
}

class _ScrollableSectionState extends State<_ScrollableSection> {
  static const _directions = [
    CLScrollDirection.both,
    CLScrollDirection.horizontal,
    CLScrollDirection.vertical,
  ];
  static const _visibilities = [
    CLScrollbarVisibility.auto,
    CLScrollbarVisibility.always,
    CLScrollbarVisibility.hidden,
  ];

  int _directionIndex = 0;
  int _visibilityIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final visibility = _visibilities[_visibilityIndex];
    final labelStyle = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );

    return _SectionCard(
      title: 'CLScrollable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 52, child: Text('方向', style: labelStyle)),
              Expanded(
                child: CLSegmentedControl(
                  key: const Key('scrollable-direction-control'),
                  segments: const ['双轴', '横向', '纵向'],
                  size: CLControlSize.small,
                  selectedIndex: _directionIndex,
                  onChanged: (index) => setState(() => _directionIndex = index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 52, child: Text('滚动条', style: labelStyle)),
              Expanded(
                child: CLSegmentedControl(
                  key: const Key('scrollable-visibility-control'),
                  segments: const ['自动', '始终', '隐藏'],
                  size: CLControlSize.small,
                  selectedIndex: _visibilityIndex,
                  onChanged: (index) =>
                      setState(() => _visibilityIndex = index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: DecoratedBox(
              decoration: clSmoothDecoration(
                color: theme.colors.panel,
                borderRadius: BorderRadius.circular(theme.radii.control),
                side: BorderSide(color: theme.colors.outline),
              ),
              child: CLScrollable(
                key: const Key('scrollable-demo'),
                direction: _directions[_directionIndex],
                horizontalScrollbar: visibility,
                verticalScrollbar: visibility,
                borderRadius: BorderRadius.circular(theme.radii.control),
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 620,
                  height: 380,
                  child: CustomPaint(
                    painter: _ScrollableDemoPainter(
                      gridColor: theme.colors.separator,
                      axisColor: theme.colors.outlineStrong,
                      nodeColor: theme.colors.accentBackground,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 20,
                          child: CLBadge(
                            '0,0',
                            color: theme.colors.controlHighlight,
                            foreground: theme.colors.textSecondary,
                          ),
                        ),
                        Positioned(
                          left: 258,
                          top: 148,
                          child: CLBadge(
                            '320×180',
                            unit: 'px',
                            color: theme.colors.accentBackground,
                            foreground: theme.colors.textPrimary,
                          ),
                        ),
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: CLBadge(
                            '620×380',
                            unit: 'px',
                            color: theme.colors.controlHighlight,
                            foreground: theme.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('拖动、滚轮，或按住 Shift 使用滚轮', style: labelStyle),
        ],
      ),
    );
  }
}

class _ScrollableDemoPainter extends CustomPainter {
  const _ScrollableDemoPainter({
    required this.gridColor,
    required this.axisColor,
    required this.nodeColor,
  });

  final Color gridColor;
  final Color axisColor;
  final Color nodeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axisPaint,
    );

    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 112,
          height: 72,
        ),
        const Radius.circular(12),
      ),
      Paint()..color = nodeColor,
    );
  }

  @override
  bool shouldRepaint(_ScrollableDemoPainter oldDelegate) {
    return gridColor != oldDelegate.gridColor ||
        axisColor != oldDelegate.axisColor ||
        nodeColor != oldDelegate.nodeColor;
  }
}

class _LazyListSection extends StatefulWidget {
  const _LazyListSection();

  @override
  State<_LazyListSection> createState() => _LazyListSectionState();
}

class _LazyListSectionState extends State<_LazyListSection> {
  static const _directions = [Axis.vertical, Axis.horizontal];
  static const _visibilities = [
    CLScrollbarVisibility.auto,
    CLScrollbarVisibility.always,
    CLScrollbarVisibility.hidden,
  ];

  int _directionIndex = 0;
  int _visibilityIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final direction = _directions[_directionIndex];
    final visibility = _visibilities[_visibilityIndex];
    final labelStyle = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );

    return _SectionCard(
      title: 'CLList',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 52, child: Text('方向', style: labelStyle)),
              Expanded(
                child: CLSegmentedControl(
                  key: const Key('list-direction-control'),
                  segments: const ['纵向', '横向'],
                  size: CLControlSize.small,
                  selectedIndex: _directionIndex,
                  onChanged: (index) => setState(() => _directionIndex = index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 52, child: Text('滚动条', style: labelStyle)),
              Expanded(
                child: CLSegmentedControl(
                  key: const Key('list-visibility-control'),
                  segments: const ['自动', '始终', '隐藏'],
                  size: CLControlSize.small,
                  selectedIndex: _visibilityIndex,
                  onChanged: (index) =>
                      setState(() => _visibilityIndex = index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: DecoratedBox(
              decoration: clSmoothDecoration(
                color: theme.colors.panel,
                borderRadius: BorderRadius.circular(theme.radii.control),
                side: BorderSide(color: theme.colors.outline),
              ),
              child: CLList.builder(
                key: const Key('list-demo'),
                scrollDirection: direction,
                scrollbarVisibility: visibility,
                borderRadius: BorderRadius.circular(theme.radii.control),
                padding: const EdgeInsets.all(8),
                itemExtent: direction == Axis.vertical ? 44 : 120,
                itemCount: 1000,
                itemBuilder: (context, index) {
                  final number = '${index + 1}'.padLeft(3, '0');
                  final content = DecoratedBox(
                    decoration: clSmoothDecoration(
                      color: index.isEven
                          ? theme.colors.control
                          : theme.colors.controlHighlight,
                      borderRadius: BorderRadius.circular(theme.radii.control),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: direction == Axis.vertical
                          ? Row(
                              children: [
                                Text('#$number', style: theme.typography.mono),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Lazily built item',
                                    style: theme.typography.callout.copyWith(
                                      color: theme.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('#$number', style: theme.typography.mono),
                                const SizedBox(height: 4),
                                Text(
                                  'Lazy item',
                                  style: theme.typography.caption.copyWith(
                                    color: theme.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                  return Padding(
                    padding: direction == Axis.vertical
                        ? const EdgeInsets.only(bottom: 4)
                        : const EdgeInsets.only(right: 4),
                    child: content,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('ListView-backed · 1000 项按需构建', style: labelStyle),
        ],
      ),
    );
  }
}
