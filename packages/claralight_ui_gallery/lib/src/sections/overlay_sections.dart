part of '../../main.dart';

class _PopoverSection extends StatefulWidget {
  const _PopoverSection();

  @override
  State<_PopoverSection> createState() => _PopoverSectionState();
}

class _PopoverSectionState extends State<_PopoverSection> {
  static const _positions = CLPopoverPosition.values;
  final _controller = CLPopoverController();
  int _positionIndex = 0;
  bool _showArrow = true;

  @override
  void initState() {
    super.initState();
    if (kAutoOpen == 'popover') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.open();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);

    return _SectionCard(
      title: 'CLPopover',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CLSegmentedControl(
            segments: const ['上', '下', '左', '右'],
            selectedIndex: _positionIndex,
            onChanged: (value) => setState(() => _positionIndex = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CLToggle(
                value: _showArrow,
                onChanged: (value) => setState(() => _showArrow = value),
              ),
              const SizedBox(width: 10),
              Text(
                '显示小尾巴',
                style: theme.typography.callout.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: CLPopover(
              controller: _controller,
              position: _positions[_positionIndex],
              showArrow: _showArrow,
              anchorBuilder: (context, controller) => CLButton(
                label: controller.isOpen ? '收起 Popover' : '打开 Popover',
                variant: CLButtonVariant.secondary,
                onPressed: controller.toggle,
              ),
              popoverBuilder: (context, controller) => SizedBox(
                width: 240,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '快速设置',
                      style: theme.typography.label.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const CLTextField(placeholder: '输入名称'),
                    const SizedBox(height: 10),
                    CLButton(label: '完成', onPressed: controller.close),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLSheet',
      child: Align(
        alignment: Alignment.centerLeft,
        child: CLButton(
          label: '弹出 Sheet',
          variant: CLButtonVariant.secondary,
          size: CLControlSize.medium,
          onPressed: () =>
              CLSheet.show(context, child: const _SheetDemoContent()),
        ),
      ),
    );
  }
}

/// Replica of the mobile mockup's watch-face sheet.
class _SheetDemoContent extends StatefulWidget {
  const _SheetDemoContent();

  @override
  State<_SheetDemoContent> createState() => _SheetDemoContentState();
}

class _SheetDemoContentState extends State<_SheetDemoContent> {
  int _screen = 0;
  int _style = 0;
  int _swatch = 1;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '神秘表盘',
              style: theme.typography.headline.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: theme.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: '小米手环 9 Pro  ',
            style: theme.typography.callout.copyWith(
              color: theme.colors.textTertiary,
            ),
            children: [
              TextSpan(
                text: '已保存',
                style: theme.typography.callout.copyWith(
                  color: theme.colors.textHint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CLSegmentedControl(
          segments: const ['亮屏', '息屏'],
          selectedIndex: _screen,
          onChanged: (i) => setState(() => _screen = i),
        ),
        const SizedBox(height: 8),
        CLListSection(
          header: '表盘样式',
          children: [
            CLListTile(
              label: '新增样式',
              outlined: true,
              leading: const Icon(Icons.add_rounded),
              size: CLControlSize.large,
              onTap: () {},
            ),
            for (final (i, label) in const ['样式 1', '样式 2', '样式 3'].indexed)
              CLListTile(
                label: label,
                size: CLControlSize.large,
                selected: _style == i,
                onTap: () => setState(() => _style = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        CLSectionHeader('表盘配色'),
        CLColorSwatchGroup(
          colors: const [
            Color(0xFF297E7B),
            Color(0xFF3F80A6),
            Color(0xFF808080),
            Color(0xFFD98C0B),
            Color(0xFFAF5356),
          ],
          selectedIndex: _swatch,
          onChanged: (i) => setState(() => _swatch = i),
        ),
        const SizedBox(height: 12),
        CLDivider(),
        Text.rich(
          TextSpan(
            text: '占用固件内存: ',
            style: theme.typography.callout
                .withCLWeight(FontWeight.w500)
                .copyWith(color: theme.colors.textTertiary),
            children: [
              TextSpan(
                text: '368KB/1024KB',
                style: theme.typography.mono.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLDialog',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          CLButton(
            label: '导出表盘',
            variant: CLButtonVariant.secondary,
            size: CLControlSize.medium,
            onPressed: () => CLDialog.show(
              context,
              title: '导出表盘',
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('请验证预览图，如有预览图错误或未上传请重新生成。'),
              ),
              actions: [
                CLButton(
                  label: '继续',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CLButton(
                  label: '刷新全部',
                  variant: CLButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          CLButton(
            key: const Key('three-action-dialog-demo'),
            label: '三选项弹窗',
            variant: CLButtonVariant.secondary,
            size: CLControlSize.medium,
            onPressed: () => CLDialog.show(
              context,
              title: '保存更改',
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('关闭前是否保存当前更改？'),
              ),
              actions: [
                CLButton(
                  label: '保存并关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CLButton(
                  label: '不保存',
                  variant: CLButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CLButton(
                  label: '取消',
                  variant: CLButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatefulWidget {
  const _MenuSection();

  @override
  State<_MenuSection> createState() => _MenuSectionState();
}

class _MenuSectionState extends State<_MenuSection> {
  bool _listView = true;
  String _sortKey = '名称';
  final GlobalKey _menuKey = GlobalKey();
  final CLMenuController _menuController = CLMenuController();

  @override
  void initState() {
    super.initState();
    if (kAutoOpen == 'menu') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        Future<void> tap(Offset at) async {
          GestureBinding.instance.handlePointerEvent(
            PointerDownEvent(pointer: 99, position: at),
          );
          await Future.delayed(const Duration(milliseconds: 90));
          GestureBinding.instance.handlePointerEvent(
            PointerUpEvent(pointer: 99, position: at),
          );
        }

        // Open/close loop so captures can catch both morph directions.
        while (mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !mounted) return;
          final center = box.localToGlobal(box.size.center(Offset.zero));
          await tap(center);
          await Future.delayed(const Duration(milliseconds: 1600));
          await tap(center.translate(0, -420));
          await Future.delayed(const Duration(milliseconds: 900));
        }
      });
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _select(VoidCallback action) {
    action();
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    Widget? checkmark(bool selected) =>
        selected ? Icon(Icons.check, color: theme.colors.textSecondary) : null;

    return _SectionCard(
      title: 'CLMenu',
      child: Row(
        children: [
          CLMenu(
            key: _menuKey,
            controller: _menuController,
            anchor: Icon(Icons.more_horiz, color: theme.colors.textSecondary),
            children: [
              const CLListTile(
                label: '选择',
                leading: Icon(Icons.check_circle_outline),
              ),
              CLListTile(
                label: '连接服务器',
                leading: const Icon(Icons.desktop_windows_outlined),
                onTap: () => _select(() {}),
              ),
              const CLDivider(),
              CLListTile(
                label: '图标',
                leading: const Icon(Icons.grid_view_outlined),
                trailing: checkmark(!_listView),
                onTap: () => _select(() => setState(() => _listView = false)),
              ),
              CLListTile(
                label: '列表',
                leading: const Icon(Icons.format_list_bulleted),
                trailing: checkmark(_listView),
                onTap: () => _select(() => setState(() => _listView = true)),
              ),
              const CLDivider(),
              for (final key in const ['名称', '种类', '日期', '标签'])
                CLListTile(
                  label: key,
                  trailing: _sortKey == key
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '升序',
                              style: theme.typography.caption.copyWith(
                                color: theme.colors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check,
                              color: theme.colors.textSecondary,
                            ),
                          ],
                        )
                      : null,
                  onTap: () => _select(() => setState(() => _sortKey = key)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '菜单内容由 CLList 与自定义行构建',
              style: theme.typography.caption.copyWith(
                color: theme.colors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
