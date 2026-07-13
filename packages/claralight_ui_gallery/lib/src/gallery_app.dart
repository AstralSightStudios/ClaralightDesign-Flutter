part of '../main.dart';

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  Brightness _brightness = Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final colors = _brightness == Brightness.light
        ? const CLColorScheme.light()
        : const CLColorScheme.dark();

    return CLTheme(
      data: CLThemeData(colors: colors),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Claralight UI Gallery',
        theme: ThemeData(useMaterial3: true, brightness: _brightness),
        home: GalleryHome(
          brightness: _brightness,
          onBrightnessChanged: (brightness) {
            setState(() => _brightness = brightness);
          },
        ),
      ),
    );
  }
}
