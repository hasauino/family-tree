import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An HSV colour wheel: the angle around the wheel selects hue, the distance
/// from the centre selects saturation, and a slider below controls brightness
/// (value). Emits the live [Color] through [onChanged] as the user drags.
class ColorWheelPicker extends StatefulWidget {
  const ColorWheelPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.size = 220,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final double size;

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  void _updateFromPosition(Offset local) {
    final r = widget.size / 2;
    final v = local - Offset(r, r);
    final sat = (v.distance / r).clamp(0.0, 1.0);
    final hue = (math.atan2(v.dy, v.dx) * 180 / math.pi + 360) % 360;
    setState(() => _hsv = _hsv.withHue(hue).withSaturation(sat));
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    final angle = _hsv.hue * math.pi / 180;
    final thumb = Offset(
      r + math.cos(angle) * _hsv.saturation * r,
      r + math.sin(angle) * _hsv.saturation * r,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanDown: (d) => _updateFromPosition(d.localPosition),
          onPanUpdate: (d) => _updateFromPosition(d.localPosition),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _WheelPainter(
                value: _hsv.value,
                thumb: thumb,
                thumbColor: _hsv.toColor(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.brightness_6_outlined, size: 18),
            Expanded(
              child: Slider(
                value: _hsv.value,
                onChanged: (v) {
                  setState(() => _hsv = _hsv.withValue(v));
                  widget.onChanged(_hsv.toColor());
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.value,
    required this.thumb,
    required this.thumbColor,
  });

  final double value;
  final Offset thumb;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final rect = Rect.fromCircle(center: center, radius: r);

    // Hue ring (angle → hue).
    final hueShader = SweepGradient(
      colors: [
        for (var h = 0; h <= 360; h += 30)
          HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
      ],
    ).createShader(rect);
    canvas.drawCircle(center, r, Paint()..shader = hueShader);

    // Saturation falls off toward the centre (white core).
    final satShader = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawCircle(center, r, Paint()..shader = satShader);

    // Brightness: darken the whole wheel as value drops.
    canvas.drawCircle(
      center,
      r,
      Paint()..color = Colors.black.withValues(alpha: 1 - value),
    );

    // Thumb marker.
    canvas.drawCircle(thumb, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumb,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black54,
    );
    canvas.drawCircle(thumb, 6, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.value != value ||
      old.thumb != thumb ||
      old.thumbColor != thumbColor;
}
