import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-cache shaders and register the debug performance monitor.
  await LiquidGlassWidgets.initialize();

  // Wrap the app with LiquidGlassWidgets to install the root backdrop scope
  // and accessibility bridge. Enable adaptiveQuality for automatic per-device tuning.
  runApp(LiquidGlassWidgets.wrap(
    child: const MyApp(),
    adaptiveQuality: true,
  ));
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
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://bing.npanuhin.me/US/en/2024-01-16.jpg'),
                fit: BoxFit.cover,
              ),
            ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
