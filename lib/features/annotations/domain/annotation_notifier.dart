import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';
import '../data/annotation_storage.dart';
import 'annotation_model.dart';
import 'annotation_state.dart';

/// Provider for AnnotationStorage.
final annotationStorageProvider = Provider<AnnotationStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AnnotationStorage(prefs);
});

/// Riverpod Notifier managing the annotation session for a specific document.
class AnnotationNotifier extends Notifier<AnnotationState> {
  final String documentId;
  static const _uuid = Uuid();

  AnnotationNotifier(this.documentId);

  AnnotationStorage get _storage => ref.read(annotationStorageProvider);

  @override
  AnnotationState build() {
    final loaded = _storage.loadAnnotations(documentId);
    return AnnotationState(annotations: loaded);
  }

  void setActiveTool(AnnotationTool tool) {
    state = state.copyWith(activeTool: tool, clearSelection: true);
  }

  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(currentStrokeWidth: width);
  }

  void selectAnnotation(String? id) {
    state = state.copyWith(selectedAnnotationId: id);
  }

  /// Start live stroke drawing.
  void startDrawing(NormalizedPoint point) {
    state = state.copyWith(
      isDrawing: true,
      activePoints: [point],
    );
  }

  /// Append points to active stroke.
  void updateDrawing(NormalizedPoint point) {
    if (!state.isDrawing) return;
    state = state.copyWith(
      activePoints: [...state.activePoints, point],
    );
  }

  /// Finish stroke and convert to permanent annotation.
  Future<void> finishDrawing(int pageNumber) async {
    if (!state.isDrawing || state.activePoints.isEmpty) {
      state = state.copyWith(isDrawing: false, activePoints: const []);
      return;
    }

    final tool = state.activeTool;
    AnnotationType type;
    double opacity = 1.0;
    double stroke = state.currentStrokeWidth;

    switch (tool) {
      case AnnotationTool.highlighter:
        type = AnnotationType.highlight;
        opacity = 0.4;
        stroke = 18.0;
        break;
      case AnnotationTool.marker:
        type = AnnotationType.ink;
        opacity = 0.85;
        stroke = 6.0;
        break;
      case AnnotationTool.pen:
      default:
        type = AnnotationType.ink;
        opacity = 1.0;
        break;
    }

    final newAnnotation = Annotation(
      id: _uuid.v4(),
      documentId: documentId,
      pageNumber: pageNumber,
      type: type,
      colorValue: state.currentColor.toARGB32(),
      strokeWidth: stroke,
      opacity: opacity,
      points: List.from(state.activePoints),
      createdAt: DateTime.now(),
    );

    _pushUndoSnapshot();
    final updated = [...state.annotations, newAnnotation];
    state = state.copyWith(
      annotations: updated,
      isDrawing: false,
      activePoints: const [],
      isDirty: true,
      redoStack: const [],
    );

    await _storage.saveAnnotations(documentId, updated);
  }

  /// Add shape or text annotation.
  Future<void> addShapeAnnotation({
    required int pageNumber,
    required AnnotationType type,
    required NormalizedRect rect,
    String? textContent,
  }) async {
    final newAnnotation = Annotation(
      id: _uuid.v4(),
      documentId: documentId,
      pageNumber: pageNumber,
      type: type,
      colorValue: state.currentColor.toARGB32(),
      strokeWidth: state.currentStrokeWidth,
      rect: rect,
      textContent: textContent,
      createdAt: DateTime.now(),
    );

    _pushUndoSnapshot();
    final updated = [...state.annotations, newAnnotation];
    state = state.copyWith(
      annotations: updated,
      isDirty: true,
      redoStack: const [],
    );

    await _storage.saveAnnotations(documentId, updated);
  }

  /// Delete annotation by ID.
  Future<void> deleteAnnotation(String id) async {
    _pushUndoSnapshot();
    final updated = state.annotations.where((a) => a.id != id).toList();
    state = state.copyWith(
      annotations: updated,
      isDirty: true,
      redoStack: const [],
      clearSelection: state.selectedAnnotationId == id,
    );
    await _storage.saveAnnotations(documentId, updated);
  }

  /// Undo last annotation operation.
  Future<void> undo() async {
    if (!state.canUndo) return;
    final previousState = state.undoStack.last;
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)..removeLast();
    final updatedRedo = List<List<Annotation>>.from(state.redoStack)..add(state.annotations);

    state = state.copyWith(
      annotations: previousState,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      isDirty: true,
    );
    await _storage.saveAnnotations(documentId, previousState);
  }

  /// Redo previous undone operation.
  Future<void> redo() async {
    if (!state.canRedo) return;
    final nextState = state.redoStack.last;
    final updatedRedo = List<List<Annotation>>.from(state.redoStack)..removeLast();
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)..add(state.annotations);

    state = state.copyWith(
      annotations: nextState,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      isDirty: true,
    );
    await _storage.saveAnnotations(documentId, nextState);
  }

  void _pushUndoSnapshot() {
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)..add(state.annotations);
    if (updatedUndo.length > 30) {
      updatedUndo.removeAt(0); // Bound undo stack to 30 snapshots
    }
    state = state.copyWith(undoStack: updatedUndo);
  }
}

/// Family provider for AnnotationNotifier scoped to document ID.
final annotationNotifierProvider = NotifierProvider.family<
    AnnotationNotifier, AnnotationState, String>(AnnotationNotifier.new);
