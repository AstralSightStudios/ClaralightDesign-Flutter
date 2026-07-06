import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

const galleryBackgroundImageUrl =
    'https://bing.npanuhin.me/US/en/2024-01-16.jpg';

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
                  _SectionTitle('SideBar'),
                  SizedBox(height: 16),
                  _SideBarExample(),
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
