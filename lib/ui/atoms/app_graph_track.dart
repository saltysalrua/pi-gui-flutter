import 'package:flutter/material.dart';
import 'package:pi_gui/core/models/commit_graph.dart';

import '../core/theme/theme_context_extensions.dart';

/// A single row of a DAG rail, stretching to the real row height. No repository
/// data, labels or interaction live in the painter.
class AppGraphTrack extends StatelessWidget {
  const AppGraphTrack({
    super.key,
    required this.row,
    required this.columns,
    this.highlighted = false,
  });
  final CommitGraphRow row;
  final int columns;
  final bool highlighted;
  static const laneWidth = 12.0;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: (columns + 1) * laneWidth,
      child: CustomPaint(
        painter: _GraphPainter(row, highlighted, [
          colors.primary,
          colors.success,
          colors.warning,
          colors.accent,
          colors.error,
        ]),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter(this.row, this.highlighted, this.colors);
  final CommitGraphRow row;
  final bool highlighted;
  final List<Color> colors;
  double x(int column) => (column + 1) * AppGraphTrack.laneWidth;
  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    Paint pen(int color) => Paint()
      ..color = colors[color % colors.length]
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final edge in row.edges) {
      final start = edge.fromNode ? middle : 0.0;
      final path = Path()..moveTo(x(edge.from), start);
      if (edge.from == edge.to) {
        path.lineTo(x(edge.to), size.height);
      } else {
        path.cubicTo(
          x(edge.from),
          start + (size.height - start) * 0.6,
          x(edge.to),
          start + (size.height - start) * 0.4,
          x(edge.to),
          size.height,
        );
      }
      canvas.drawPath(path, pen(edge.color));
    }
    final center = Offset(x(row.column), middle);
    if (row.incoming) {
      canvas.drawLine(Offset(center.dx, 0), center, pen(row.color));
    }
    canvas.drawCircle(
      center,
      3,
      Paint()..color = colors[row.color % colors.length],
    );
    if (highlighted) canvas.drawCircle(center, 5.5, pen(row.color));
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      row != oldDelegate.row ||
      highlighted != oldDelegate.highlighted ||
      colors != oldDelegate.colors;
}
