import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

const galleryBackgroundImageUrl =
    'https://bing.npanuhin.me/US/en/2024-01-16.jpg';

/// When launched with --dart-define=MENU_AUTOPILOT=true, the liquid menu
/// demo replays the reference recording's interaction with synthetic
/// pointer events so the animation can be screen-captured hands-free.
const bool kMenuAutopilot = bool.fromEnvironment('MENU_AUTOPILOT');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Claralight UI Gallery',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const MyHomePage(title: 'Claralight UI Gallery'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        fit: StackFit.expand,
        children: const [
          _GalleryBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('CLButton'),
                  SizedBox(height: 16),
                  _ButtonShowcase(),
                  SizedBox(height: 32),
                  _SectionTitle('IconButton'),
                  SizedBox(height: 16),
                  CLIconButtonExample(),
                  SizedBox(height: 32),
                  _SectionTitle('Toggle'),
                  SizedBox(height: 16),
                  CLToggleExample(),
                  SizedBox(height: 32),
                  _SectionTitle('SideBar'),
                  SizedBox(height: 16),
                  _SideBarExample(),
                  SizedBox(height: 32),
                  _SectionTitle('LiquidMenu'),
                  SizedBox(height: 16),
                  LiquidMenuDemo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBackground extends StatelessWidget {
  const _GalleryBackground();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      galleryBackgroundImageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172435), Color(0xFF1E1F25), Color(0xFF312027)],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: const Color(0xFFF1F0EA),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ButtonShowcase extends StatelessWidget {
  const _ButtonShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 20,
      children: const [
        _GalleryItem(
          label: 'Primary with both icons',
          child: CLButton(
            label: '继续',
            leadingIcon: Icon(Icons.select_all_rounded),
            trailingIcon: Icon(Icons.arrow_forward_rounded),
          ),
        ),
        _GalleryItem(
          label: 'Neutral with leading icon',
          child: CLButton(
            width: 300,
            label: '继续',
            variant: CLButtonVariant.neutral,
            leadingIcon: Icon(Icons.select_all_rounded),
          ),
        ),
        _GalleryItem(
          label: 'Danger without icons',
          child: CLButton(
            width: 260,
            label: '继续',
            variant: CLButtonVariant.danger,
          ),
        ),
        _GalleryItem(
          label: 'Trailing icon keeps centered text',
          child: CLButton(
            width: 320,
            label: '继续',
            trailingIcon: Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ],
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final String label;
  final Widget child;

  const _GalleryItem({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 354,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFFDAD6CB)),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class CLIconButtonExample extends StatelessWidget {
  const CLIconButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CLIconButton(icon: Icons.add_rounded, onPressed: () {}),
        const SizedBox(width: 12),
        CLIconButton(icon: Icons.favorite_rounded, onPressed: () {}),
      ],
    );
  }
}

class CLToggleExample extends StatefulWidget {
  const CLToggleExample({super.key});

  @override
  State<CLToggleExample> createState() => _CLToggleExampleState();
}

class _CLToggleExampleState extends State<CLToggleExample> {
  var _value = false;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 20,
      children: [
        _GalleryItem(
          label: 'Interactive toggle',
          child: CLToggle(
            value: _value,
            onChanged: (value) => setState(() => _value = value),
          ),
        ),
        const _GalleryItem(
          label: 'Disabled off',
          child: CLToggle(value: false, onChanged: null),
        ),
        const _GalleryItem(
          label: 'Disabled on',
          child: CLToggle(value: true, onChanged: null),
        ),
      ],
    );
  }
}

class _SideBarExample extends StatelessWidget {
  const _SideBarExample();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: CLSideBar(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Overview'),
              SizedBox(height: 8),
              Text('Components'),
              SizedBox(height: 8),
              Text('Tokens'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replica of the iOS 26 Files app screen from the reference recording.
class LiquidMenuDemo extends StatefulWidget {
  const LiquidMenuDemo({super.key});

  @override
  State<LiquidMenuDemo> createState() => _LiquidMenuDemoState();
}

class _LiquidMenuDemoState extends State<LiquidMenuDemo> {
  bool _listView = true;
  String _sortKey = '标签';
  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (kMenuAutopilot) _autoplay();
  }

  void _dispatch(PointerEvent event) {
    GestureBinding.instance.handlePointerEvent(event);
  }

  Future<void> _press(
    Offset at, {
    Duration hold = Duration.zero,
    Offset? dragTo,
    Duration drag = Duration.zero,
  }) async {
    _dispatch(PointerDownEvent(pointer: 99, position: at));
    var current = at;
    if (dragTo != null) {
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        await Future.delayed(drag ~/ steps);
        current = Offset.lerp(
          at,
          dragTo,
          Curves.easeInOut.transform(i / steps),
        )!;
        _dispatch(PointerMoveEvent(pointer: 99, position: current));
      }
    }
    await Future.delayed(hold);
    _dispatch(PointerUpEvent(pointer: 99, position: current));
  }

  Future<void> _autoplay() async {
    // Loops forever so a screen capture can start at any time.
    while (mounted) {
      await _autoplayOnce();
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }

  Future<void> _autoplayOnce() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final button = box.localToGlobal(box.size.center(Offset.zero));

    // Open the menu, like the first click in the recording.
    await _press(button, hold: const Duration(milliseconds: 90));
    await Future.delayed(const Duration(milliseconds: 1300));

    // Panel is anchored to the button's top right corner.
    final panelTopLeft = Offset(button.dx + 22 - 260, button.dy - 22);
    Offset row(double y) => panelTopLeft + Offset(80, y);
    // Rows: pad10 + 44(选择) + 44(连接服务器) + sep19 + 图标 center.
    final iconRow = row(10 + 88 + 19 + 22);
    final listRow = row(10 + 88 + 19 + 44 + 22);
    final nameRow = row(10 + 176 + 38 + 22);
    final tagRow = row(10 + 176 + 38 + 176 + 28);

    // Press 名称, drag down to 标签 while the glow follows, release.
    await _press(
      nameRow,
      dragTo: tagRow,
      drag: const Duration(milliseconds: 900),
      hold: const Duration(milliseconds: 500),
    );
    await Future.delayed(const Duration(milliseconds: 1400));

    // Open again, then press 图标 and hold so the glow spreads out.
    await _press(button, hold: const Duration(milliseconds: 90));
    await Future.delayed(const Duration(milliseconds: 1300));
    await _press(iconRow, hold: const Duration(milliseconds: 700));
    await Future.delayed(const Duration(milliseconds: 1400));

    // Open once more and dismiss by tapping outside.
    await _press(button, hold: const Duration(milliseconds: 90));
    await Future.delayed(const Duration(milliseconds: 1200));
    await _press(
      listRow.translate(-160, 120),
      hold: const Duration(milliseconds: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 380,
        height: 640,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            // Background chrome of the fake Files app.
            const Positioned(
              top: 24,
              left: 20,
              child: Row(
                children: [
                  Icon(Icons.chevron_left, color: Color(0xFF9E9E9E), size: 28),
                ],
              ),
            ),
            const Positioned(
              top: 62,
              left: 20,
              child: Text(
                '项目',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Color(0xFF8E8E93), size: 20),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '搜索',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Icon(Icons.mic, color: Color(0xFFB5B5BA), size: 20),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_filled,
                      color: Color(0xFF98989F),
                      size: 44,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '无最近项目',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The liquid glass menu, anchored top right like the recording.
            Positioned(
              top: 18,
              right: 16,
              child: CLLiquidMenu(
                key: _menuKey,
                menuWidth: 260,
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
                      for (final key in const ['名称', '种类', '日期', '大小', '标签'])
                        CLMenuAction(
                          label: key,
                          checked: _sortKey == key,
                          subtitle: _sortKey == key ? '升序' : null,
                          onSelected: () => setState(() => _sortKey = key),
                        ),
                    ],
                  ),
                  CLMenuGroup(
                    actions: [CLMenuAction(label: '显示选项', onSelected: () {})],
                  ),
                ],
                child: const Icon(Icons.more_horiz, color: Color(0xFFEDEDED)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
