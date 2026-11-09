import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/annotation_model.dart';

/// Canvas painter that renders vector annotations on a PDF page overlay.
class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<NormalizedPoint> activePoints;
  final Color activeColor;
  final double activeStrokeWidth;
  final bool isDrawing;
  final AnnotationTool activeTool;
  final String? selectedId;

  AnnotationPainter({
    required this.annotations,
    required this.activePoints,
    required this.activeColor,
    required this.activeStrokeWidth,
    required this.isDrawing,
    required this.activeTool,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw saved annotations
    for (final ann in annotations) {
      _drawAnnotation(canvas, size, ann, ann.id == selectedId);
    }

    // 2. Draw active in-progress stroke
    if (isDrawing && activePoints.length > 1) {
      _drawActiveStroke(canvas, size);
    }
  }

  void _drawAnnotation(Canvas canvas, Size size, Annotation ann, bool isSelected) {
    final paint = Paint()
      ..color = ann.color
      ..strokeWidth = ann.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (ann.type == AnnotationType.highlight) {
      paint.blendMode = BlendMode.multiply;
      paint.strokeCap = StrokeCap.square;
    }

    switch (ann.type) {
      case AnnotationType.ink:
      case AnnotationType.highlight:
        if (ann.points.length > 1) {
          final path = Path();
          final first = ann.points.first.toOffset(size);
          path.moveTo(first.dx, first.dy);

          for (int i = 1; i < ann.points.length; i++) {
            final p1 = ann.points[i - 1].toOffset(size);
            final p2 = ann.points[i].toOffset(size);
            final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
            path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
          }
          final last = ann.points.last.toOffset(size);
          path.lineTo(last.dx, last.dy);
          canvas.drawPath(path, paint);
        }
        break;

      case AnnotationType.rectangle:
        if (ann.rect != null) {
          final rect = ann.rect!.toRect(size);
          canvas.drawRect(rect, paint);
        }
        break;

      case AnnotationType.circle:
        if (ann.rect != null) {
          final rect = ann.rect!.toRect(size);
          canvas.drawOval(rect, paint);
        }
        break;

      case AnnotationType.arrow:
        if (ann.points.length >= 2) {
          final start = ann.points.first.toOffset(size);
          final end = ann.points.last.toOffset(size);
          _drawArrow(canvas, start, end, paint);
        }
        break;

      case AnnotationType.stickyNote:
        if (ann.rect != null) {
          final rect = ann.rect!.toRect(size);
          final notePaint = Paint()
            ..color = ann.color.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), notePaint);
        }
        break;

      default:
        break;
    }

    if (isSelected && ann.rect != null) {
      final selectPaint = Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRect(ann.rect!.toRect(size).inflate(4), selectPaint);
    }
  }

  void _drawActiveStroke(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = activeTool == AnnotationTool.highlighter
          ? activeColor.withValues(alpha: 0.4)
          : activeColor
      ..strokeWidth = activeTool == AnnotationTool.highlighter ? 18.0 : activeStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = activeTool == AnnotationTool.highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (activeTool == AnnotationTool.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final path = Path();
    final first = activePoints.first.toOffset(size);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < activePoints.length; i++) {
      final p1 = activePoints[i - 1].toOffset(size);
      final p2 = activePoints[i].toOffset(size);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
    }
    final last = activePoints.last.toOffset(size);
    path.lineTo(last.dx, last.dy);

    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowSize = 14.0;
    const arrowAngle = math.pi / 6;

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - arrowAngle),
        end.dy - arrowSize * math.sin(angle - arrowAngle),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + arrowAngle),
        end.dy - arrowSize * math.sin(angle + arrowAngle),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return true;
  }
}
