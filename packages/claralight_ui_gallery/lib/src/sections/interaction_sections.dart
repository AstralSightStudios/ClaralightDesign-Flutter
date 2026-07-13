part of '../../main.dart';

class _ToolbarSection extends StatefulWidget {
  const _ToolbarSection();

  @override
  State<_ToolbarSection> createState() => _ToolbarSectionState();
}

class _ToolbarSectionState extends State<_ToolbarSection> {
  int _activeTool = 3;

  @override
  Widget build(BuildContext context) {
    const tools = [
      (Icons.image_outlined, '图像'),
      (Icons.title_rounded, '文字'),
      (Icons.data_usage_rounded, '数据'),
      (Icons.auto_awesome_outlined, '效果'),
    ];
    return _SectionCard(
      title: 'CLToolbar',
      child: Row(
        children: [
          CLToolbar(
            children: [
              for (final (index, tool) in tools.indexed)
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

class _TooltipSection extends StatelessWidget {
  const _TooltipSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLTooltip',
      child: Row(
        children: [
          CLTooltip(
            message: '这按钮是干嘛的',
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
    );
  }
}
