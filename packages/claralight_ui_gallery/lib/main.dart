import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

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
      title: 'Claralight UI Gallery',
      home: const MyHomePage(title: 'Claralight UI Gallery'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage('https://bing.npanuhin.me/US/en/2024-01-16.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SingleChildScrollView(
            child: Flex(
              direction: Axis.vertical,
              children: [
                const Text(
                  'Buttons',
                  style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                ),
                Flex(
                  direction: Axis.vertical,
                  children: [
                    Text("IconButton"),
                    CLIconButton(icon: Icons.add, onPressed: () {}),
                    Text("SideBar"),
                    CLSideBar(child: Flex(direction: Axis.vertical,children: [Text("11111111111111111"),Text("11111111111111111"),Text("11111111111111111")])),
                    Text("LiquidMenu"),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LiquidMenuDemo(),
                    ),
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

  Future<void> _press(Offset at, {Duration hold = Duration.zero, Offset? dragTo, Duration drag = Duration.zero}) async {
    _dispatch(PointerDownEvent(pointer: 99, position: at));
    var current = at;
    if (dragTo != null) {
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        await Future.delayed(drag ~/ steps);
        current = Offset.lerp(at, dragTo, Curves.easeInOut.transform(i / steps))!;
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
    await _press(nameRow,
        dragTo: tagRow,
        drag: const Duration(milliseconds: 900),
        hold: const Duration(milliseconds: 500));
    await Future.delayed(const Duration(milliseconds: 1400));

    // Open again, then press 图标 and hold so the glow spreads out.
    await _press(button, hold: const Duration(milliseconds: 90));
    await Future.delayed(const Duration(milliseconds: 1300));
    await _press(iconRow, hold: const Duration(milliseconds: 700));
    await Future.delayed(const Duration(milliseconds: 1400));

    // Open once more and dismiss by tapping outside.
    await _press(button, hold: const Duration(milliseconds: 90));
    await Future.delayed(const Duration(milliseconds: 1200));
    await _press(listRow.translate(-160, 120), hold: const Duration(milliseconds: 60));
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
            Positioned(
              top: 24,
              left: 20,
              child: Row(
                children: const [
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
                child: Row(
                  children: const [
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
                    Icon(Icons.access_time_filled,
                        color: Color(0xFF98989F), size: 44),
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
                  CLMenuGroup(actions: [
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
                  ]),
                  CLMenuGroup(actions: [
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
                  ]),
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
                  CLMenuGroup(actions: [
                    CLMenuAction(
                      label: '显示选项',
                      onSelected: () {},
                    ),
                  ]),
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
