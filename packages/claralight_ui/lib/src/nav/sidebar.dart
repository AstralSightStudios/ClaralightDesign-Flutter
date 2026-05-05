import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class CLSideBar extends StatelessWidget {
    final Widget child;

    const CLSideBar({
        super.key,
        required this.child,
    });

    @override
    Widget build(BuildContext context) {
        return GlassCard(
            quality: GlassQuality.premium,
            useOwnLayer: true,
            child: child,
        );
    }
}
