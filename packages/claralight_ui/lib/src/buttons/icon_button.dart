import 'package:flutter/material.dart';

import 'package:claralight_ui/src/surfaces/glass.dart';

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
        return GestureDetector(
            onTap: onPressed,
            child: Glass(
                borderRadius: BorderRadius.circular(999),
                padding: const EdgeInsets.all(12),
                child: Icon(icon),
            ),
        );
    }
}
