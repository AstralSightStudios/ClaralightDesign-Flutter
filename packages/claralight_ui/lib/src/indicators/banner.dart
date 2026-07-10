import 'package:flutter/widgets.dart';

import '../foundation/shape.dart';
import '../theme/theme.dart';

/// Tone of a [CLBanner].
enum CLBannerTone { info, warning, danger, success }

/// A Claralight inline hint banner — the amber "上传图片素材尺寸需保持一致"
/// strip of the desktop mockup.
///
/// A tinted rounded rectangle with an optional leading icon and a single
/// line (or few lines) of tinted text.
class CLBanner extends StatelessWidget {
  final String message;
  final CLBannerTone tone;

  /// Optional leading icon; defaults to none.
  final Widget? icon;

  final EdgeInsetsGeometry padding;

  const CLBanner(
    this.message, {
    super.key,
    this.tone = CLBannerTone.warning,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final colors = theme.colors;

    final (foreground, background) = switch (tone) {
      CLBannerTone.info => (
        colors.textSecondary,
        colors.control,
      ),
      CLBannerTone.warning => (colors.warning, colors.warningBackground),
      CLBannerTone.danger => (colors.danger, colors.dangerBackground),
      CLBannerTone.success => (
        colors.success,
        colors.success.withValues(alpha: 0.14),
      ),
    };

    return DecoratedBox(
      decoration: clSmoothDecoration(
        color: background,
        borderRadius: BorderRadius.circular(theme.radii.control),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: foreground, size: 16),
                child: icon!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: theme.typography.callout.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
