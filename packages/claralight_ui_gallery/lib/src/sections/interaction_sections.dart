part of '../../main.dart';

class _ToolbarSection extends StatefulWidget {
  const _ToolbarSection();

  @override
  State<_ToolbarSection> createState() => _ToolbarSectionState();
}

class _ToolbarSectionState extends State<_ToolbarSection> {
  int _activeTool = 3;
  double _overflowWidth = 260;

  @override
  Widget build(BuildContext context) {
    const tools = [
      (Icons.image_outlined, '图像'),
      (Icons.title_rounded, '文字'),
      (Icons.data_usage_rounded, '数据'),
      (Icons.auto_awesome_outlined, '效果'),
      (Icons.crop_rounded, '裁剪'),
      (Icons.tune_rounded, '调整'),
      (Icons.ios_share_rounded, '导出'),
    ];
    final overflowItems = [
      for (final (index, tool) in tools.indexed)
        CLOverflowToolbarItem<int>(
          id: index,
          extent: 36,
          retention: index < 4
              ? CLToolbarItemRetention.pinned
              : CLToolbarItemRetention.overflowable,
          overflowPriority: index,
          toolbarBuilder: (context) => CLIconButton(
            key: Key('overflow-toolbar-tool-$index'),
            icon: tool.$1,
            semanticLabel: tool.$2,
            size: CLControlSize.medium,
            selected: _activeTool == index,
            onPressed: () => setState(() => _activeTool = index),
          ),
          overflowBuilder: index < 4
              ? null
              : (context, closeMenu) => CLListTile(
                  label: tool.$2,
                  leading: Icon(tool.$1),
                  selected: _activeTool == index,
                  onTap: () {
                    setState(() => _activeTool = index);
                    closeMenu();
                  },
                ),
        ),
    ];

    return _SectionCard(
      title: 'CLToolbar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CLToolbar(
                children: [
                  for (final (index, tool) in tools.take(4).indexed)
                    CLIconButton(
                      key: Key('toolbar-tool-$index'),
                      icon: tool.$1,
                      semanticLabel: tool.$2,
                      size: CLControlSize.medium,
                      selected: _activeTool == index,
                      onPressed: () => setState(() => _activeTool = index),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              CLToolbar(
                dividers: true,
                children: [
                  CLIconButton(
                    icon: Icons.info_outline_rounded,
                    size: CLControlSize.medium,
                    onPressed: () {},
                  ),
                  CLIconButton(
                    icon: Icons.zoom_in_rounded,
                    size: CLControlSize.medium,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('7 项工具 · 拖动滑块调整宽度'),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: CLSlider(
                  value: (_overflowWidth - 120) / 228,
                  onChanged: (value) =>
                      setState(() => _overflowWidth = 120 + value * 228),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_overflowWidth.round()}px'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: _overflowWidth,
            child: CLOverflowToolbar<int>(
              items: overflowItems,
              overflowExtent: 36,
              overflowTriggerBuilder: (context, hiddenIds, toggle) =>
                  CLIconButton(
                    icon: Icons.more_horiz_rounded,
                    semanticLabel: '更多工具',
                    size: CLControlSize.medium,
                    selected: hiddenIds.isNotEmpty,
                    onPressed: toggle,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTabsSection extends StatefulWidget {
  const _ChipTabsSection();

  @override
  State<_ChipTabsSection> createState() => _ChipTabsSectionState();
}

class _ChipTabsSectionState extends State<_ChipTabsSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLChipTabs',
      child: CLChipTabs(
        tabs: const ['时间日期', '运动健康', '工具数据'],
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _ColorPickerSection extends StatefulWidget {
  const _ColorPickerSection();

  @override
  State<_ColorPickerSection> createState() => _ColorPickerSectionState();
}

class _ColorPickerSectionState extends State<_ColorPickerSection> {
  Color _color = const Color(0xFF3F80A6);

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLColorPicker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CLColorPicker(
            color: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
        ],
      ),
    );
  }
}

class _TooltipSection extends StatefulWidget {
  const _TooltipSection();

  @override
  State<_TooltipSection> createState() => _TooltipSectionState();
}

class _TooltipSectionState extends State<_TooltipSection> {
  static const _positions = CLPopoverPosition.values;
  int _positionIndex = 0;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLTooltip',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CLSegmentedControl(
            key: const Key('tooltip-position-control'),
            segments: const ['上', '下', '左', '右'],
            selectedIndex: _positionIndex,
            onChanged: (value) => setState(() => _positionIndex = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CLTooltip(
                key: const Key('tooltip-demo'),
                message: '这按钮是干嘛的',
                position: _positions[_positionIndex],
                child: CLIconButton(
                  icon: Icons.help_outline_rounded,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '悬停或长按查看提示',
                  style: CLTheme.of(context).typography.caption.copyWith(
                    color: CLTheme.of(context).colors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
