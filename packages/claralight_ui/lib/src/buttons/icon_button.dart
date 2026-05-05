import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class IconButton extends StatelessWidget {
    final IconData icon;
    final VoidCallback onPressed;

    const IconButton({
        super.key,
        required this.icon,
        required this.onPressed,
    });

    @override
    Widget build(BuildContext context) {
        return GlassButton(
            onTap: onPressed,
            icon: Icon(icon),
        );
    }
}
