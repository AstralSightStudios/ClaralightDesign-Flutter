import 'package:flutter/material.dart';

import 'package:claralight_ui/src/surfaces/interactive_glass.dart';

class CLIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const CLIconButton({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InteractiveGlass(
      onTap: onPressed,
      blur: 3,
      child: Icon(icon, color: const Color(0xFFEDEDED)),
    );
  }
}
