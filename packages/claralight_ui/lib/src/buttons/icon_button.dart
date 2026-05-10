import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class CLIconButton extends StatelessWidget {
    final IconData icon;
    final VoidCallback onPressed;

    const CLIconButton({
        super.key,
        required this.icon,
        required this.onPressed,
    });

    @override
    Widget build(BuildContext context) {
        return GlassIconButton(
            icon: Icon(icon),
            useOwnLayer: true,
            onPressed: onPressed,
        );
    }
}
