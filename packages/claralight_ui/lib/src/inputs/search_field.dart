import 'package:flutter/cupertino.dart';

import '../foundation/control_size.dart';
import 'text_field.dart';

/// A Claralight search field — the "搜索" bar of the mockups.
///
/// A [CLTextField] preset with a leading search glyph and an optional
/// trailing widget (e.g. a microphone icon).
class CLSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final CLControlSize size;
  final double? width;

  const CLSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.size = CLControlSize.large,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return CLTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      prefix: const Icon(CupertinoIcons.search),
      suffix: trailing,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      size: size,
      width: width,
    );
  }
}
