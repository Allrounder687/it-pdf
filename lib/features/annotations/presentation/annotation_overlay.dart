import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/annotation_model.dart';
import '../domain/annotation_notifier.dart';
import 'annotation_painter.dart';

/// Overlay widget placed directly on top of each PDF page in the viewer.
/// Renders only draft (uncommitted) annotations to prevent double-rendering
/// over natively rendered burned PDF annotations.
class AnnotationOverlay extends ConsumerWidget {
  final String documentId;
  final int pageNumber;
  final Size pageSize;

  const AnnotationOverlay({
    super.key,
    required this.documentId,
    required this.pageNumber,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annotationState = ref.watch(annotationNotifierProvider(documentId));
    final notifier = ref.read(annotationNotifierProvider(documentId).notifier);
    final isToolActive = annotationState.activeTool != AnnotationTool.none;

    // Render only uncommitted draft annotations
    final pageAnnotations = annotationState.draftAnnotationsForPage(pageNumber);

    return Positioned.fill(
      child: GestureDetector(
        behavior: isToolActive
            ? HitTestBehavior.opaque
            : HitTestBehavior.translucent,
        onPanStart: isToolActive
            ? (details) {
                final point = NormalizedPoint.fromOffset(
                  details.localPosition,
                  pageSize,
                );
                notifier.startDrawing(point);
              }
            : null,
        onPanUpdate: isToolActive
            ? (details) {
                final point = NormalizedPoint.fromOffset(
                  details.localPosition,
                  pageSize,
                );
                notifier.updateDrawing(point);
              }
            : null,
        onPanEnd: isToolActive
            ? (_) {
                notifier.finishDrawing(pageNumber);
              }
            : null,
        child: CustomPaint(
          size: pageSize,
          painter: AnnotationPainter(
            annotations: pageAnnotations,
            activePoints: annotationState.isDrawing
                ? annotationState.activePoints
                : const [],
            activeColor: annotationState.currentColor,
            activeStrokeWidth: annotationState.currentStrokeWidth,
            isDrawing: annotationState.isDrawing,
            activeTool: annotationState.activeTool,
            selectedId: annotationState.selectedAnnotationId,
          ),
        ),
      ),
    );
  }
}
