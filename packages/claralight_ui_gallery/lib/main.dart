import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

/// Initial scroll offset for hands-free screenshot verification, e.g.
/// --dart-define=GALLERY_SCROLL=2200.
const double kInitialScroll =
    // ignore: avoid_double_and_int_checks
    1.0 * int.fromEnvironment('GALLERY_SCROLL');

/// Auto-opens a popup demo after launch for hands-free screenshots:
/// --dart-define=AUTO_OPEN=dialog|sheet|menu.
const String kAutoOpen = String.fromEnvironment('AUTO_OPEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CLScrollable.precache();
  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CLTheme(
      data: CLThemeData(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Claralight UI Gallery',
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const GalleryHome(),
      ),
    );
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  final _scroll = ScrollController(initialScrollOffset: kInitialScroll);

  @override
  void initState() {
    super.initState();
    if (kAutoOpen == 'dialog' ||
        kAutoOpen == 'sheet' ||
        kAutoOpen == 'picker') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (kAutoOpen == 'picker') {
          CLColorPicker.show(context, color: const Color(0xFF297E7B));
        } else if (kAutoOpen == 'dialog') {
          CLDialog.show(
            context,
            title: '导出表盘',
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text('请验证预览图，如有预览图错误或未上传请重新生成。'),
            ),
            actions: [
              CLButton(label: '继续', onPressed: () {}),
              CLButton(
                label: '刷新全部',
                variant: CLButtonVariant.secondary,
                onPressed: () {},
              ),
            ],
          );
        } else {
          CLSheet.show(context, child: const _SheetDemoContent());
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: CLScrollable(
            key: const Key('gallery-scroll'),
            direction: CLScrollDirection.vertical,
            verticalController: _scroll,
            horizontalScrollbar: CLScrollbarVisibility.hidden,
            // Extra top inset keeps the heading clear of the macOS traffic
            // lights (the window content extends into the title bar).
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claralight UI',
                  style: theme.typography.display.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ClaraLight 设计语言 · 扁平分层 · 弹性交互',
                  style: theme.typography.callout.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),
                const Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _ButtonsSection(),
                    _IconButtonsSection(),
                    _TogglesSection(),
                    _SegmentedSection(),
                    _SliderSection(),
                    _InputsSection(),
                    _SelectSection(),
                    _ScrollableSection(),
                    _LazyListSection(),
                    _ListsSection(),
                    _SwatchesSection(),
                    _ProgressSection(),
                    _StatusSection(),
                    _ToolbarSection(),
                    _ChipTabsSection(),
                    _ColorPickerSection(),
                    _TooltipSection(),
                    _SheetSection(),
                    _DialogSection(),
                    _MenuSection(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A mockup-style panel wrapping one gallery section.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return SizedBox(
      width: 380,
      child: CLPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.typography.label.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLButton',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CLButton(
            label: '继续',
            leadingIcon: const Icon(Icons.check_rounded),
            onPressed: () {},
          ),
          CLButton(
            label: '次要',
            variant: CLButtonVariant.secondary,
            onPressed: () {},
          ),
          CLButton(
            label: '幽灵',
            variant: CLButtonVariant.ghost,
            onPressed: () {},
          ),
          CLButton(
            label: '删除',
            variant: CLButtonVariant.danger,
            onPressed: () {},
          ),
          const CLButton(label: '禁用'),
          CLButton(
            label: '中',
            size: CLControlSize.medium,
            variant: CLButtonVariant.secondary,
            onPressed: () {},
          ),
          CLButton(
            label: '小',
            size: CLControlSize.small,
            variant: CLButtonVariant.secondary,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _IconButtonsSection extends StatefulWidget {
  const _IconButtonsSection();

  @override
  State<_IconButtonsSection> createState() => _IconButtonsSectionState();
}

class _IconButtonsSectionState extends State<_IconButtonsSection> {
  int _alignment = 0;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLIconButton',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CLIconButton(icon: Icons.add_rounded, onPressed: () {}),
              const SizedBox(width: 8),
              CLIconButton(icon: Icons.favorite_rounded, onPressed: () {}),
              const SizedBox(width: 8),
              CLIconButton(
                icon: Icons.ios_share_rounded,
                fill: CLTheme.of(context).colors.accent,
                iconColor: CLTheme.of(context).colors.onAccent,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              const CLIconButton(icon: Icons.block_rounded, onPressed: null),
            ],
          ),
          const SizedBox(height: 12),
          // The alignment grid of the desktop mockup: small rounded squares.
          Row(
            children: [
              for (final (i, icon) in const [
                Icons.format_align_left_rounded,
                Icons.format_align_center_rounded,
                Icons.format_align_right_rounded,
                Icons.vertical_align_top_rounded,
                Icons.vertical_align_center_rounded,
                Icons.vertical_align_bottom_rounded,
              ].indexed) ...[
                CLIconButton(
                  icon: icon,
                  size: CLControlSize.small,
                  shape: CLIconButtonShape.rounded,
                  selected: _alignment == i,
                  onPressed: () => setState(() => _alignment = i),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TogglesSection extends StatefulWidget {
  const _TogglesSection();

  @override
  State<_TogglesSection> createState() => _TogglesSectionState();
}

class _TogglesSectionState extends State<_TogglesSection> {
  bool _value = true;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLToggle',
      child: Row(
        children: [
          CLToggle(value: _value, onChanged: (v) => setState(() => _value = v)),
          const SizedBox(width: 16),
          const CLToggle(value: false, onChanged: null),
          const SizedBox(width: 16),
          const CLToggle(value: true, onChanged: null),
        ],
      ),
    );
  }
}

class _SegmentedSection extends StatefulWidget {
  const _SegmentedSection();

  @override
  State<_SegmentedSection> createState() => _SegmentedSectionState();
}

class _SegmentedSectionState extends State<_SegmentedSection> {
  int _screen = 0;
  int _tool = 1;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLSegmentedControl',
      child: Column(
        children: [
          CLSegmentedControl(
            segments: const ['亮屏', '息屏'],
            selectedIndex: _screen,
            onChanged: (i) => setState(() => _screen = i),
          ),
          const SizedBox(height: 10),
          CLSegmentedControl(
            segments: const ['名称', '种类', '日期'],
            size: CLControlSize.medium,
            selectedIndex: _tool,
            onChanged: (i) => setState(() => _tool = i),
          ),
        ],
      ),
    );
  }
}

class _SliderSection extends StatefulWidget {
  const _SliderSection();

  @override
  State<_SliderSection> createState() => _SliderSectionState();
}

class _SliderSectionState extends State<_SliderSection> {
  double _value = 0.62;

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    return _SectionCard(
      title: 'CLSlider',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CLSlider(value: _value, onChanged: (v) => setState(() => _value = v)),
          const SizedBox(height: 4),
          Text(
            '${(_value * 100).round()}%',
            style: theme.typography.caption.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const CLSlider(value: 0.3, onChanged: null),
        ],
      ),
    );
  }
}

class _InputsSection extends StatelessWidget {
  const _InputsSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLTextField / CLSearchField',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CLTextField(
                  size: CLControlSize.small,
                  mono: true,
                  prefix: const Text('X'),
                  suffix: const Text('px'),
                  controller: TextEditingController(text: '12'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CLTextField(
                  size: CLControlSize.small,
                  mono: true,
                  prefix: const Text('Y'),
                  suffix: const Text('px'),
                  controller: TextEditingController(text: '12'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const CLSearchField(
            placeholder: '搜索',
            trailing: Icon(Icons.mic_rounded),
          ),
        ],
      ),
    );
  }
}

class _SelectSection extends StatefulWidget {
  const _SelectSection();

  @override
  State<_SelectSection> createState() => _SelectSectionState();
}

class _SelectSectionState extends State<_SelectSection> {
  static final _largeOptionSet = List.generate(
    500,
    (index) => CLSelectOption(
      index,
      '项目 ${(index + 1).toString().padLeft(3, '0')} / 500',
    ),
    growable: false,
  );

  String _fillMode = '数字填充';
  int _selectedItem = 249;
  final _widthController = TextEditingController(text: '78');
  final _heightController = TextEditingController(text: '91');

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLSelect / numeric CLTextField',
      child: Column(
        children: [
          CLSelect<String>(
            size: CLControlSize.medium,
            value: _fillMode,
            options: const [
              CLSelectOption('数字填充', '数字填充'),
              CLSelectOption('图片填充', '图片填充'),
              CLSelectOption('序列帧', '序列帧'),
            ],
            onChanged: (v) => setState(() => _fillMode = v),
          ),
          const SizedBox(height: 10),
          CLSelect<int>(
            key: const Key('large-select-demo'),
            size: CLControlSize.medium,
            value: _selectedItem,
            options: _largeOptionSet,
            onChanged: (value) => setState(() => _selectedItem = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CLTextField(
                  controller: _widthController,
                  keyboardType: TextInputType.number,
                  prefix: const Text('W'),
                  suffix: const Text('px'),
                  step: 1,
                  min: 1,
                  max: 480,
                  size: CLControlSize.small,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CLTextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  prefix: const Text('H'),
                  suffix: const Text('px'),
                  step: 1,
                  min: 1,
                  max: 480,
                  size: CLControlSize.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
              decoration: BoxDecoration(
                color: theme.colors.panel,
                border: Border.all(color: theme.colors.outline),
                borderRadius: BorderRadius.circular(theme.radii.control),
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
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
              decoration: BoxDecoration(
                color: theme.colors.panel,
                border: Border.all(color: theme.colors.outline),
                borderRadius: BorderRadius.circular(theme.radii.control),
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
                    decoration: BoxDecoration(
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
        onChanged: (i) => setState(() => _selected = i)
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

class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLToolbar',
      child: Row(
        children: [
          CLToolbar(
            children: [
              CLIconButton(
                icon: Icons.image_outlined,
                size: CLControlSize.medium,
                fill: const Color(0x00000000),
                onPressed: () {},
              ),
              CLIconButton(
                icon: Icons.title_rounded,
                size: CLControlSize.medium,
                fill: const Color(0x00000000),
                onPressed: () {},
              ),
              CLIconButton(
                icon: Icons.data_usage_rounded,
                size: CLControlSize.medium,
                fill: const Color(0x00000000),
                onPressed: () {},
              ),
              CLIconButton(
                icon: Icons.auto_awesome_outlined,
                size: CLControlSize.medium,
                fill: const Color(0x00000000),
                onPressed: () {},
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
                fill: const Color(0x00000000),
                onPressed: () {},
              ),
              CLIconButton(
                icon: Icons.zoom_in_rounded,
                size: CLControlSize.medium,
                fill: const Color(0x00000000),
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
            swatches: const [
              Color(0xFF297E7B),
              Color(0xFF3F80A6),
              Color(0xFF808080),
              Color(0xFFD98C0B),
              Color(0xFFAF5356),
            ],
            onChanged: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: CLButton(
              label: '弹窗选色',
              variant: CLButtonVariant.secondary,
              size: CLControlSize.medium,
              onPressed: () async {
                final picked = await CLColorPicker.show(context, color: _color);
                if (picked != null && mounted) {
                  setState(() => _color = picked);
                }
              },
            ),
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: CLButton(
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
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLMenu',
      child: Row(
        children: [
          CLMenu(
            key: _menuKey,
            groups: [
              CLMenuGroup(
                actions: [
                  const CLMenuAction(
                    label: '选择',
                    icon: Icons.check_circle_outline,
                    enabled: false,
                  ),
                  CLMenuAction(
                    label: '连接服务器',
                    icon: Icons.desktop_windows_outlined,
                    onSelected: () {},
                  ),
                ],
              ),
              CLMenuGroup(
                actions: [
                  CLMenuAction(
                    label: '图标',
                    icon: Icons.grid_view_outlined,
                    checked: !_listView,
                    onSelected: () => setState(() => _listView = false),
                  ),
                  CLMenuAction(
                    label: '列表',
                    icon: Icons.format_list_bulleted,
                    checked: _listView,
                    onSelected: () => setState(() => _listView = true),
                  ),
                ],
              ),
              CLMenuGroup(
                actions: [
                  for (final key in const ['名称', '种类', '日期', '标签'])
                    CLMenuAction(
                      label: key,
                      checked: _sortKey == key,
                      subtitle: _sortKey == key ? '升序' : null,
                      onSelected: () => setState(() => _sortKey = key),
                    ),
                ],
              ),
            ],
            child: Icon(
              Icons.more_horiz,
              color: CLTheme.of(context).colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '按住行拖动可看到光晕跟随',
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
