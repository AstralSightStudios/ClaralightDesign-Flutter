import 'package:flutter/material.dart';

import 'package:claralight_ui/src/surfaces/glass.dart';

class CLSideBar extends StatelessWidget {
    final Widget child;

    const CLSideBar({
        super.key,
        required this.child,
    });

    @override
    Widget build(BuildContext context) {
        return Glass(
            blur: 12,
            borderRadius: BorderRadius.circular(24),
            child: child,
        );
    }
}
