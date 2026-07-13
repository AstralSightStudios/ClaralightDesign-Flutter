part of '../../main.dart';

class _ListsSection extends StatefulWidget {
  const _ListsSection();

  @override
  State<_ListsSection> createState() => _ListsSectionState();
}

class _ListsSectionState extends State<_ListsSection> {
  int _selectedStyle = 0;
  bool _groupExpanded = true;
  bool _containerExpanded = true;
  bool _subtreeExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return _SectionCard(
      title: 'CLTreeView / CLListSection / CLListTile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CLListSection(
            header: '表盘样式',
            children: [
              CLListTile(
                label: '新增样式',
                outlined: true,
                leading: const Icon(Icons.add_rounded),
                onTap: () {},
              ),
              for (final (i, label) in const ['样式 1', '样式 2', '样式 3'].indexed)
                CLListTile(
                  label: label,
                  selected: _selectedStyle == i,
                  onTap: () => setState(() => _selectedStyle = i),
                ),
            ],
          ),
          CLDivider(indent: theme.spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 282,
              height: 316,
              child: CLTreeView(
                children: [
                  CLListTile(
                    label: 'Frame 114',
                    leading: const Icon(Icons.image_outlined),
                    selected: true,
                    onTap: () {},
                  ),
                  CLListTile(
                    label: '图组 1',
                    leading: const Icon(Icons.collections_outlined),
                    onTap: () {},
                  ),
                  CLListTile(
                    label: '文字 1',
                    leading: const Icon(Icons.text_fields_rounded),
                    onTap: () {},
                  ),
                  CLListTile(
                    label: '组 2',
                    leading: const Icon(Icons.crop_free_rounded),
                    expanded: _groupExpanded,
                    onExpandedChanged: (v) =>
                        setState(() => _groupExpanded = v),
                    onTap: () =>
                        setState(() => _groupExpanded = !_groupExpanded),
                  ),
                  if (_groupExpanded) ...[
                    CLListTile(
                      label: '进度条 1',
                      depth: 1,
                      leading: const Icon(Icons.data_usage_rounded),
                      onTap: () {},
                    ),
                    CLListTile(
                      label: '序列帧 1',
                      depth: 1,
                      leading: const Icon(Icons.auto_awesome_rounded),
                      onTap: () {},
                    ),
                  ],
                  CLListTile(
                    label: '容器 1',
                    tint: const Color(0xFFBE93E4),
                    leading: const Icon(Icons.grid_view_rounded),
                    expanded: _containerExpanded,
                    onExpandedChanged: (v) =>
                        setState(() => _containerExpanded = v),
                    onTap: () => setState(
                      () => _containerExpanded = !_containerExpanded,
                    ),
                  ),
                  if (_containerExpanded) ...[
                    CLListTile(
                      label: '组 1',
                      tint: const Color(0xFFBE93E4),
                      depth: 1,
                      leading: const Icon(Icons.crop_free_rounded),
                      expanded: _subtreeExpanded,
                      onExpandedChanged: (v) =>
                          setState(() => _subtreeExpanded = v),
                      onTap: () =>
                          setState(() => _subtreeExpanded = !_subtreeExpanded),
                    ),
                    if (_subtreeExpanded) ...[
                      CLListTile(
                        label: '矩形 1',
                        tint: const Color(0xFFBE93E4),
                        depth: 2,
                        leading: const Icon(Icons.rectangle_outlined),
                        onTap: () {},
                      ),
                      CLListTile(
                        label: '文字 2',
                        tint: const Color(0xFFBE93E4),
                        depth: 2,
                        leading: const Icon(Icons.text_fields_rounded),
                        onTap: () {},
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchesSection extends StatefulWidget {
  const _SwatchesSection();

  @override
  State<_SwatchesSection> createState() => _SwatchesSectionState();
}

class _SwatchesSectionState extends State<_SwatchesSection> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLColorSwatchGroup',
      child: CLColorSwatchGroup(
        colors: const [
          Color(0xFF2E9E8F),
          Color(0xFF4A7FA8),
          Color(0xFF9E9E9E),
          Color(0xFFE0930F),
          Color(0xFFC2504B),
        ],
        selectedIndex: _selected,
        onChanged: (i) => setState(() => _selected = i),
      ),
    );
  }
}

class _ProgressSection extends StatefulWidget {
  const _ProgressSection();

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  double _progress = 368 / 1024;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return _SectionCard(
      title: 'CLProgressBar / CLProgressRing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(
              () => _progress = _progress > 0.9 ? 0.15 : _progress + 0.25,
            ),
            child: CLProgressBar(value: _progress),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: '占用固件内存: ',
              style: theme.typography.callout
                  .withCLWeight(FontWeight.w500)
                  .copyWith(color: theme.colors.textTertiary),
              children: [
                TextSpan(
                  text: '${(_progress * 1024).round()}KB/1024KB',
                  style: theme.typography.mono.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: CLProgressBar(value: null)),
              const SizedBox(width: 16),
              CLProgressRing(
                value: _progress,
                child: Text(
                  '${(_progress * 100).round()}',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textPrimary,
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

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLBanner / CLBadge',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CLBanner(
            '上传图片素材尺寸需保持一致',
            icon: Icon(Icons.lightbulb_outline_rounded),
          ),
          const SizedBox(height: 8),
          const CLBanner('已连接到设备', tone: CLBannerTone.success),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              const CLBadge('78x91', unit: 'px'),
              const CLBadge('12', unit: 'px', color: Color(0xFFEF5F00)),
              CLBadge(
                'BETA',
                color: CLTheme.of(context).colors.selection,
                foreground: CLTheme.of(context).colors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
