import 'package:flutter/material.dart';
import 'annotation_model.dart';

/// State representation for document annotations and editing session.
class AnnotationState {
  final List<Annotation> annotations;
  final AnnotationTool activeTool;
  final Color currentColor;
  final double currentStrokeWidth;
  final String? selectedAnnotationId;
  final List<List<Annotation>> undoStack;
  final List<List<Annotation>> redoStack;
  final bool isDirty;
  final bool isDrawing;
  final List<NormalizedPoint> activePoints;

  const AnnotationState({
    this.annotations = const [],
    this.activeTool = AnnotationTool.none,
    this.currentColor = const Color(0xFFFFEB3B), // Classic yellow highlight default
    this.currentStrokeWidth = 3.0,
    this.selectedAnnotationId,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isDirty = false,
    this.isDrawing = false,
    this.activePoints = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  /// Get all draft (uncommitted) annotations.
  List<Annotation> get draftAnnotations =>
      annotations.where((a) => !a.isCommitted).toList();

  /// Get all annotations for a specific page.
  List<Annotation> annotationsForPage(int page) {
    return annotations.where((a) => a.pageNumber == page).toList();
  }

  /// Get only draft (uncommitted) annotations for a specific page,
  /// preventing already-burned PDF annotations from double-rendering.
  List<Annotation> draftAnnotationsForPage(int page) {
    return annotations.where((a) => a.pageNumber == page && !a.isCommitted).toList();
  }

  AnnotationState copyWith({
    List<Annotation>? annotations,
    AnnotationTool? activeTool,
    Color? currentColor,
    double? currentStrokeWidth,
    String? selectedAnnotationId,
    List<List<Annotation>>? undoStack,
    List<List<Annotation>>? redoStack,
    bool? isDirty,
    bool? isDrawing,
    List<NormalizedPoint>? activePoints,
    bool clearSelection = false,
  }) {
    return AnnotationState(
      annotations: annotations ?? this.annotations,
      activeTool: activeTool ?? this.activeTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      selectedAnnotationId: clearSelection ? null : (selectedAnnotationId ?? this.selectedAnnotationId),
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isDirty: isDirty ?? this.isDirty,
      isDrawing: isDrawing ?? this.isDrawing,
      activePoints: activePoints ?? this.activePoints,
    );
  }
}
