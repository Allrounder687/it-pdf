import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/safe_document_storage.dart';
import '../data/annotation_storage.dart';
import 'annotation_model.dart';
import 'annotation_state.dart';

/// Provider for SyncfusionPdfService.
final syncfusionPdfServiceProvider = Provider<SyncfusionPdfService>((ref) {
  return SyncfusionPdfService();
});

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
  SyncfusionPdfService get _pdfEngine => ref.read(syncfusionPdfServiceProvider);
  SafeDocumentStorage get _safeStorage => ref.read(safeDocumentStorageProvider);

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
    state = state.copyWith(isDrawing: true, activePoints: [point]);
  }

  /// Append points to active stroke.
  void updateDrawing(NormalizedPoint point) {
    if (!state.isDrawing) return;
    state = state.copyWith(activePoints: [...state.activePoints, point]);
  }

  /// Finish stroke and convert to permanent annotation.
  Future<void> finishDrawing(int pageNumber) async {
    if (!state.isDrawing || state.activePoints.isEmpty) {
      state = state.copyWith(isDrawing: false, activePoints: const []);
      return;
    }

    final tool = state.activeTool;

    // Handle eraser
    if (tool == AnnotationTool.eraser) {
      _eraseNearbyAnnotations(pageNumber, state.activePoints);
      state = state.copyWith(isDrawing: false, activePoints: const []);
      return;
    }

    AnnotationType type;
    double opacity = 1.0;
    double stroke = state.currentStrokeWidth;
    NormalizedRect? rect;
    List<NormalizedPoint> points = List.from(state.activePoints);

    final first = points.first;
    final last = points.last;

    switch (tool) {
      case AnnotationTool.highlighter:
        type = AnnotationType.highlight;
        opacity = 0.4;
        stroke = 18.0;
        // Compute bounding rect across all points so both text markup and ink renderers succeed
        double minX = first.x, maxX = first.x, minY = first.y, maxY = first.y;
        for (final p in points) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }
        rect = NormalizedRect(left: minX, top: minY, right: maxX, bottom: maxY);
        break;

      case AnnotationTool.marker:
        type = AnnotationType.ink;
        opacity = 0.85;
        stroke = 6.0;
        break;

      case AnnotationTool.arrow:
        type = AnnotationType.arrow;
        points = [first, last];
        stroke = stroke.clamp(1.5, 6.0);
        break;

      case AnnotationTool.rectangle:
        type = AnnotationType.rectangle;
        rect = NormalizedRect(
          left: first.x < last.x ? first.x : last.x,
          top: first.y < last.y ? first.y : last.y,
          right: first.x > last.x ? first.x : last.x,
          bottom: first.y > last.y ? first.y : last.y,
        );
        break;

      case AnnotationTool.circle:
        type = AnnotationType.circle;
        rect = NormalizedRect(
          left: first.x < last.x ? first.x : last.x,
          top: first.y < last.y ? first.y : last.y,
          right: first.x > last.x ? first.x : last.x,
          bottom: first.y > last.y ? first.y : last.y,
        );
        break;

      case AnnotationTool.underline:
        type = AnnotationType.underline;
        rect = NormalizedRect(
          left: first.x < last.x ? first.x : last.x,
          top: first.y < last.y ? first.y : last.y,
          right: first.x > last.x ? first.x : last.x,
          bottom: (first.y > last.y ? first.y : last.y) + 0.02,
        );
        break;

      case AnnotationTool.strikethrough:
        type = AnnotationType.strikethrough;
        rect = NormalizedRect(
          left: first.x < last.x ? first.x : last.x,
          top: first.y < last.y ? first.y : last.y,
          right: first.x > last.x ? first.x : last.x,
          bottom: (first.y > last.y ? first.y : last.y) + 0.02,
        );
        break;

      case AnnotationTool.stickyNote:
        type = AnnotationType.stickyNote;
        const noteSize = 0.04;
        rect = NormalizedRect(
          left: (last.x - noteSize / 2).clamp(0.0, 1.0 - noteSize),
          top: (last.y - noteSize / 2).clamp(0.0, 1.0 - noteSize),
          right: (last.x + noteSize / 2).clamp(noteSize, 1.0),
          bottom: (last.y + noteSize / 2).clamp(noteSize, 1.0),
        );
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
      points: points,
      rect: rect,
      isCommitted: false, // New annotations start as uncommitted drafts
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

  void _eraseNearbyAnnotations(int pageNumber, List<NormalizedPoint> points) {
    if (points.isEmpty) return;
    final pageAnns = state.annotations
        .where((a) => a.pageNumber == pageNumber)
        .toList();
    final toDeleteIds = <String>{};

    for (final ann in pageAnns) {
      if (ann.rect != null) {
        for (final p in points) {
          if (p.x >= ann.rect!.left &&
              p.x <= ann.rect!.right &&
              p.y >= ann.rect!.top &&
              p.y <= ann.rect!.bottom) {
            toDeleteIds.add(ann.id);
            break;
          }
        }
      } else {
        for (final p in points) {
          for (final annPt in ann.points) {
            final distSq =
                (p.x - annPt.x) * (p.x - annPt.x) +
                (p.y - annPt.y) * (p.y - annPt.y);
            if (distSq < 0.001) {
              toDeleteIds.add(ann.id);
              break;
            }
          }
          if (toDeleteIds.contains(ann.id)) break;
        }
      }
    }

    if (toDeleteIds.isNotEmpty) {
      _pushUndoSnapshot();
      final updated = state.annotations
          .where((a) => !toDeleteIds.contains(a.id))
          .toList();
      state = state.copyWith(annotations: updated, isDirty: true);
      _storage.saveAnnotations(documentId, updated);
    }
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
      isCommitted: false,
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
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)
      ..removeLast();
    final updatedRedo = List<List<Annotation>>.from(state.redoStack)
      ..add(state.annotations);

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
    final updatedRedo = List<List<Annotation>>.from(state.redoStack)
      ..removeLast();
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)
      ..add(state.annotations);

    state = state.copyWith(
      annotations: nextState,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      isDirty: true,
    );
    await _storage.saveAnnotations(documentId, nextState);
  }

  /// Permanently burns all draft annotations into the PDF file structure (ISO 32000).
  /// Once validation succeeds, marks annotations as committed so they are no longer
  /// rendered in the overlay widget, preventing double-rendering.
  /// If saving to a new file destination (Save As) and no annotations are pending,
  /// the source document is safely replicated so the destination is never left empty.
  Future<bool> burnAnnotationsToFile(
    String sourceFilePath,
    String destinationPath,
  ) async {
    final toBurn = state.draftAnnotations;
    if (toBurn.isEmpty) {
      if (sourceFilePath != destinationPath) {
        try {
          final src = File(sourceFilePath);
          if (await src.exists()) {
            final bytes = await src.readAsBytes();
            final saveRes = await _safeStorage.transactionalSaveBytes(
              targetPath: destinationPath,
              bytes: bytes,
            );
            if (!saveRes.isSuccess) {
              return false;
            }
          } else {
            return false;
          }
        } catch (_) {
          return false;
        }
      }
      state = state.copyWith(isDirty: false);
      return true;
    }

    try {
      await _pdfEngine.burnAnnotationsToPdf(
        sourcePath: sourceFilePath,
        annotations: toBurn,
        outputPath: destinationPath,
      );

      // Successfully burned: mark all as committed only if saving original in-place
      if (sourceFilePath == destinationPath) {
        final updated = state.annotations
            .map((a) => a.copyWith(isCommitted: true))
            .toList();
        state = state.copyWith(annotations: updated, isDirty: false);
        await _storage.saveAnnotations(documentId, updated);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _pushUndoSnapshot() {
    final updatedUndo = List<List<Annotation>>.from(state.undoStack)
      ..add(state.annotations);
    if (updatedUndo.length > 30) {
      updatedUndo.removeAt(0);
    }
    state = state.copyWith(undoStack: updatedUndo);
  }
}

/// Family provider for AnnotationNotifier scoped to document ID.
final annotationNotifierProvider =
    NotifierProvider.family<AnnotationNotifier, AnnotationState, String>(
      AnnotationNotifier.new,
    );
