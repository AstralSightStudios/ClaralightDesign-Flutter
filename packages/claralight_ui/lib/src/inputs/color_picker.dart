import 'package:flutter/widgets.dart';

import '../buttons/button.dart';
import '../containers/dialog.dart';
import '../foundation/control_size.dart';
import '../foundation/shape.dart';
import '../indicators/color_swatch.dart';
import '../theme/theme.dart';
import 'text_field.dart';

/// A ClaraLight color picker.
///
/// A saturation/value area with a draggable loupe, a hue bar, a hex field
/// and optional preset [swatches] — all in the flat layered style. Embed it
/// inline or present it modally with [CLColorPicker.show].
class CLColorPicker extends StatefulWidget {
  /// Currently selected color.
  final Color color;

  /// Called continuously while the user picks.
  final ValueChanged<Color> onChanged;

  /// Optional preset swatch row shown under the hex field.
  final List<Color> swatches;

  /// Height of the saturation/value area.
  final double areaHeight;

  /// Corner radius of the SV area, preview chip and hex field. Null uses
  /// the theme's medium radius, which sits optically concentric inside a
  /// [CLDialog] (36 outer − 24 content inset ≈ 12).
  final double? cornerRadius;

  const CLColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.swatches = const [],
    this.areaHeight = 160,
    this.cornerRadius,
  });

  /// Presents a picker in a [CLDialog] and resolves with the chosen color,
  /// or null when dismissed.
  static Future<Color?> show(
    BuildContext context, {
    required Color color,
    List<Color> swatches = const [],
    String title = '选择颜色',
  }) async {
    var current = color;
    return CLDialog.show<Color>(
      context,
      title: title,
      maxWidth: 360,
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CLColorPicker(
              color: current,
              swatches: swatches,
              onChanged: (c) => setState(() => current = c),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CLButton(
                    label: '确定',
                    size: CLControlSize.medium,
                    onPressed: () => Navigator.of(context).pop(current),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CLButton(
                    label: '取消',
                    variant: CLButtonVariant.secondary,
                    size: CLControlSize.medium,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<CLColorPicker> createState() => _CLColorPickerState();
}

class _CLColorPickerState extends State<CLColorPicker> {
  late HSVColor _hsv;
  late final TextEditingController _hex;
  bool _editingHex = false;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
    _hex = TextEditingController(text: _hexOf(widget.color));
  }

  @override
  void didUpdateWidget(CLColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != oldWidget.color &&
        widget.color != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.color);
      _syncHex();
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _hexOf(Color color) {
    final argb = color.toARGB32();
    return (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  void _syncHex() {
    if (!_editingHex) _hex.text = _hexOf(_hsv.toColor());
  }

  void _emit(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _syncHex();
    widget.onChanged(hsv.toColor());
  }

  void _submitHex(String raw) {
    var text = raw.trim().replaceFirst('#', '');
    if (text.length == 3) {
      text = text.split('').map((c) => '$c$c').join();
    }
    final value = int.tryParse(text, radix: 16);
    _editingHex = false;
    if (text.length == 6 && value != null) {
      _emit(HSVColor.fromColor(Color(0xFF000000 | value)));
    } else {
      _syncHex();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final color = _hsv.toColor();
    final radius = widget.cornerRadius ?? theme.radii.medium;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.areaHeight,
          child: _SVArea(hsv: _hsv, cornerRadius: radius, onChanged: _emit),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 16,
          child: _HueBar(hue: _hsv.hue, onChanged: (h) {
            _emit(_hsv.withHue(h));
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: clSmoothDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
                side: BorderSide(color: theme.colors.outline),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onFocusChange: (focused) {
                  if (focused) {
                    _editingHex = true;
                  } else {
                    _submitHex(_hex.text);
                  }
                },
                child: CLTextField(
                  controller: _hex,
                  mono: true,
                  size: CLControlSize.medium,
                  borderRadius: radius,
                  prefix: const Text('#'),
                  onSubmitted: _submitHex,
                ),
              ),
            ),
          ],
        ),
        if (widget.swatches.isNotEmpty) ...[
          const SizedBox(height: 12),
          CLColorSwatchGroup(
            colors: widget.swatches,
            selectedIndex: _swatchIndex(color),
            onChanged: (i) =>
                _emit(HSVColor.fromColor(widget.swatches[i])),
          ),
        ],
      ],
    );
  }

  int? _swatchIndex(Color color) {
    for (var i = 0; i < widget.swatches.length; i++) {
      if (widget.swatches[i].toARGB32() == color.toARGB32()) return i;
    }
    return null;
  }
}

/// Saturation (x) / value (y) area with a loupe thumb.
class _SVArea extends StatelessWidget {
  final HSVColor hsv;
  final double cornerRadius;
  final ValueChanged<HSVColor> onChanged;

  const _SVArea({
    required this.hsv,
    required this.cornerRadius,
    required this.onChanged,
  });

  void _pick(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final theme = CLTheme.of(context);
    final radius = BorderRadius.circular(cornerRadius);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final thumb = Offset(
          hsv.saturation * size.width,
          (1 - hsv.value) * size.height,
        );

        return GestureDetector(
          key: const Key('cl-color-picker-sv'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _pick(d.localPosition, size),
          onPanUpdate: (d) => _pick(d.localPosition, size),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRSuperellipse(
                  borderRadius: radius,
                  child: CustomPaint(painter: _SVPainter(hue: hsv.hue)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: clSmoothDecoration(
                      borderRadius: radius,
                      side: BorderSide(color: theme.colors.outline),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumb.dx - 9,
                top: thumb.dy - 9,
                child: _Loupe(color: hsv.toColor()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SVPainter extends CustomPainter {
  final double hue;

  const _SVPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFFFFF), hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SVPainter oldDelegate) => hue != oldDelegate.hue;
}

/// Rainbow hue slider.
class _HueBar extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueBar({required this.hue, required this.onChanged});

  static const _hues = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  void _pick(Offset local, double width) {
    onChanged((local.dx / width).clamp(0.0, 1.0) * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final x = (hue / 360) * width;

        return GestureDetector(
          key: const Key('cl-color-picker-hue'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _pick(d.localPosition, width),
          onPanUpdate: (d) => _pick(d.localPosition, width),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(colors: _hues),
                    shape: clSmoothShape(
                      BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (x - 9).clamp(-2.0, width - 16),
                top: (height - 18) / 2,
                child: _Loupe(
                  color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The white-ringed round thumb shared by the SV area and hue bar.
class _Loupe extends StatelessWidget {
  final Color color;

  const _Loupe({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

