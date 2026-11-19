import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'signal_buffer.dart';

/// Stacked traces, one lane per channel, each centered on its mean and
/// scaled to its own peak so channels with different offsets stay visible.
class SignalPlot extends StatelessWidget {
  const SignalPlot({super.key, required this.buffer, required this.labels});

  final SignalBuffer buffer;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SignalPainter(
          buffer,
          labels,
          scheme.primary,
          scheme.onSurfaceVariant,
          scheme.outlineVariant,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  _SignalPainter(this.buffer, this.labels, this.line, this.text, this.grid)
    : super(repaint: buffer);

  final SignalBuffer buffer;
  final List<String> labels;
  final Color line;
  final Color text;
  final Color grid;

  static const _labelWidth = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    final lanes = buffer.channels;
    if (lanes == 0) return;
    final laneHeight = size.height / lanes;
    final plotWidth = size.width - _labelWidth;
    final dx = plotWidth / (buffer.capacity - 1);
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()..color = grid;

    for (var c = 0; c < lanes; c++) {
      final top = c * laneHeight;
      final mid = top + laneHeight / 2;
      canvas.drawLine(
        Offset(_labelWidth, mid),
        Offset(size.width, mid),
        gridPaint,
      );
      _label(canvas, c < labels.length ? labels[c] : '#$c', top, laneHeight);

      final n = buffer.length;
      if (n < 2) continue;
      var mean = 0.0;
      for (var i = 0; i < n; i++) {
        mean += buffer.at(c, i);
      }
      mean /= n;
      var peak = 1e-9;
      for (var i = 0; i < n; i++) {
        peak = math.max(peak, (buffer.at(c, i) - mean).abs());
      }
      final scale = (laneHeight / 2 * 0.9) / peak;
      // Newest sample at the right edge.
      final x0 = _labelWidth + (buffer.capacity - n) * dx;
      final path = Path()..moveTo(x0, mid - (buffer.at(c, 0) - mean) * scale);
      for (var i = 1; i < n; i++) {
        path.lineTo(x0 + i * dx, mid - (buffer.at(c, i) - mean) * scale);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  void _label(Canvas canvas, String label, double top, double height) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: text, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _labelWidth - 4);
    tp.paint(canvas, Offset(0, top + (height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_SignalPainter old) =>
      old.buffer != buffer ||
      old.labels != labels ||
      old.line != line ||
      old.text != text;
}
