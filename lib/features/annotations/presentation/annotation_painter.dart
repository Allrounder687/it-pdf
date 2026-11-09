import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/annotation_model.dart';

/// Canvas painter that renders vector annotations on a PDF page overlay.
/// Supports smooth freehand ink, highlighters, text markups, shapes, arrows, and sticky notes.
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
    // 1. Draw persistent annotations
    for (final ann in annotations) {
      _drawAnnotation(canvas, size, ann, ann.id == selectedId);
    }

    // 2. Draw active in-progress gesture / stroke
    if (isDrawing && activePoints.length > 1) {
      _drawActiveGesture(canvas, size);
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
        } else if (ann.rect != null && ann.type == AnnotationType.highlight) {
          final fillPaint = Paint()
            ..color = ann.color.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.multiply;
          canvas.drawRect(ann.rect!.toRect(size), fillPaint);
        }
        break;

      case AnnotationType.underline:
        if (ann.rect != null) {
          final rect = ann.rect!.toRect(size);
          final linePaint = Paint()
            ..color = ann.color
            ..strokeWidth = ann.strokeWidth.clamp(1.5, 4.0)
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(rect.left, rect.bottom - 1),
            Offset(rect.right, rect.bottom - 1),
            linePaint,
          );
        }
        break;

      case AnnotationType.strikethrough:
        if (ann.rect != null) {
          final rect = ann.rect!.toRect(size);
          final linePaint = Paint()
            ..color = ann.color
            ..strokeWidth = ann.strokeWidth.clamp(1.5, 4.0)
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(rect.left, rect.center.dy),
            Offset(rect.right, rect.center.dy),
            linePaint,
          );
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
            ..color = ann.color.withValues(alpha: 0.95)
            ..style = PaintingStyle.fill;
          final shadowPaint = Paint()
            ..color = Colors.black26
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.shift(const Offset(1, 1)), const Radius.circular(4)),
            shadowPaint,
          );
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), notePaint);

          // Draw note glyph lines
          final glyphPaint = Paint()
            ..color = Colors.black54
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          final startX = rect.left + 4;
          final endX = rect.right - 4;
          if (endX > startX) {
            canvas.drawLine(Offset(startX, rect.top + 6), Offset(endX, rect.top + 6), glyphPaint);
            canvas.drawLine(Offset(startX, rect.top + 10), Offset(endX, rect.top + 10), glyphPaint);
          }
        }
        break;

      case AnnotationType.textCallout:
        if (ann.rect != null && ann.textContent != null) {
          final rect = ann.rect!.toRect(size);
          final bgPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), bgPaint);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);

          final textSpan = TextSpan(
            text: ann.textContent,
            style: TextStyle(color: ann.color, fontSize: 12),
          );
          final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
          textPainter.layout(maxWidth: rect.width - 4);
          textPainter.paint(canvas, Offset(rect.left + 2, rect.top + 2));
        }
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

  void _drawActiveGesture(Canvas canvas, Size size) {
    final start = activePoints.first.toOffset(size);
    final end = activePoints.last.toOffset(size);

    final paint = Paint()
      ..color = activeTool == AnnotationTool.highlighter
          ? activeColor.withValues(alpha: 0.4)
          : activeColor
      ..strokeWidth = activeTool == AnnotationTool.highlighter ? 18.0 : activeStrokeWidth
      ..style = (activeTool == AnnotationTool.stickyNote) ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = activeTool == AnnotationTool.highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (activeTool == AnnotationTool.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    switch (activeTool) {
      case AnnotationTool.arrow:
        _drawArrow(canvas, start, end, paint);
        break;

      case AnnotationTool.rectangle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawRect(rect, paint);
        break;

      case AnnotationTool.circle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawOval(rect, paint);
        break;

      case AnnotationTool.underline:
        final rect = Rect.fromPoints(start, end);
        canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.right, rect.bottom), paint);
        break;

      case AnnotationTool.strikethrough:
        final rect = Rect.fromPoints(start, end);
        canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), paint);
        break;

      case AnnotationTool.stickyNote:
        final rect = Rect.fromLTWH(end.dx - 14, end.dy - 14, 28, 28);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
        break;

      default:
        // Freehand ink / marker / highlighter
        final path = Path();
        path.moveTo(start.dx, start.dy);
        for (int i = 1; i < activePoints.length; i++) {
          final p1 = activePoints[i - 1].toOffset(size);
          final p2 = activePoints[i].toOffset(size);
          final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
        }
        path.lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
        break;
    }
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
