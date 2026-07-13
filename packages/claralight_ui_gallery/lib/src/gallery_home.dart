part of '../main.dart';

class GalleryHome extends StatefulWidget {
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  const GalleryHome({
    super.key,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  final _scroll = ScrollController(initialScrollOffset: kInitialScroll);

  @override
  void initState() {
    super.initState();
    if (kAutoOpen == 'dialog' || kAutoOpen == 'sheet') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (kAutoOpen == 'dialog') {
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Text(
                      'Claralight UI',
                      style: theme.typography.display.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    SizedBox(
                      width: 156,
                      child: CLSegmentedControl(
                        key: const Key('theme-mode-control'),
                        segments: const ['浅色', '深色'],
                        selectedIndex: widget.brightness == Brightness.light
                            ? 0
                            : 1,
                        onChanged: (index) {
                          widget.onBrightnessChanged(
                            index == 0 ? Brightness.light : Brightness.dark,
                          );
                        },
                        size: CLControlSize.small,
                      ),
                    ),
                  ],
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
                    _PopoverSection(),
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
