import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/pdf_content_editing_backend.dart';
import '../data/pdf_edit_save_service.dart';
import '../data/pdfium_editing_backend.dart';
import 'editor_state.dart';
import 'pdf_content_object.dart';
import 'pdf_edit_history.dart';
import 'pdf_edit_transaction.dart';

final pdfEditingBackendProvider = Provider<PdfContentEditingBackend>((ref) {
  return PdfiumEditingBackend();
});

final pdfEditSaveServiceProvider = Provider<PdfEditSaveService>((ref) {
  final backend = ref.watch(pdfEditingBackendProvider);
  return PdfEditSaveService(backend: backend);
});

class EditorNotifierParams {
  final String documentId;
  final String documentPath;

  const EditorNotifierParams({
    required this.documentId,
    required this.documentPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorNotifierParams &&
          runtimeType == other.runtimeType &&
          documentId == other.documentId &&
          documentPath == other.documentPath;

  @override
  int get hashCode => documentId.hashCode ^ documentPath.hashCode;
}

final editorNotifierProvider =
    NotifierProvider.family<EditorNotifier, EditorState, EditorNotifierParams>(
      EditorNotifier.new,
    );

/// State notifier managing PDF content selection, object mutations, undo/redo, and persistence.
class EditorNotifier extends Notifier<EditorState> {
  final EditorNotifierParams params;
  final PdfEditHistory _history = PdfEditHistory();
  final List<PdfEditOperation> _pendingOperations = [];
  final Uuid _uuid = const Uuid();

  EditorNotifier(this.params);

  PdfContentEditingBackend get _backend => ref.read(pdfEditingBackendProvider);
  PdfEditSaveService get _saveService => ref.read(pdfEditSaveServiceProvider);

  @override
  EditorState build() {
    return EditorState(
      documentId: params.documentId,
      documentPath: params.documentPath,
    );
  }

  /// Switches overall workspace mode (Read, Annotate, Edit, Forms).
  void setWorkspaceMode(WorkspaceMode mode) {
    state = state.copyWith(workspaceMode: mode);
    if (mode == WorkspaceMode.edit && state.extractedObjectsByPage.isEmpty) {
      // Auto-load current page objects
      loadPageObjects(0);
    }
  }

  /// Sets the active editing tool.
  void setActiveTool(EditorTool tool) {
    state = state.copyWith(activeTool: tool, clearActiveEditingObjectId: true);
  }

  /// Toggles visibility of the inspector properties panel.
  void togglePropertiesPanel() {
    state = state.copyWith(isPropertiesPanelOpen: !state.isPropertiesPanelOpen);
  }

  /// Extracts page objects from the authentic PDF file.
  Future<void> loadPageObjects(int pageIndex) async {
    if (state.extractedObjectsByPage.containsKey(pageIndex)) return;

    state = state.copyWith(isLoading: true);
    try {
      final objects = await _backend.extractPageObjects(
        filePath: state.documentPath,
        pageIndex: pageIndex,
      );
      final paragraphs = await _backend.extractParagraphs(
        filePath: state.documentPath,
        pageIndex: pageIndex,
      );

      final updatedObjects = Map<int, List<PdfContentObject>>.from(
        state.extractedObjectsByPage,
      )..[pageIndex] = objects;

      final updatedParagraphs = Map<int, List<PdfParagraphBlock>>.from(
        state.paragraphsByPage,
      )..[pageIndex] = paragraphs;

      state = state.copyWith(
        extractedObjectsByPage: updatedObjects,
        paragraphsByPage: updatedParagraphs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to extract PDF objects: $e',
      );
    }
  }

  /// Selects an object on the page.
  void selectObject(String objectId, {bool multiSelect = false}) {
    final newSelection = multiSelect
        ? (Set<String>.from(state.selectedObjectIds)..add(objectId))
        : {objectId};

    // Auto-sync style controls to selected object
    Color textColor = state.currentTextColor;
    Color strokeColor = state.currentStrokeColor;
    Color fillColor = state.currentFillColor;
    double strokeWidth = state.currentStrokeWidth;
    String fontName = state.currentFontName;
    double fontSize = state.currentFontSize;
    bool bold = state.currentBold;
    bool italic = state.currentItalic;

    final obj = _findObject(objectId);
    if (obj != null) {
      fillColor = obj.fillColor;
      strokeColor = obj.strokeColor;
      strokeWidth = obj.strokeWidth;
      if (obj is PdfTextContentObject) {
        textColor = obj.fillColor;
        fontName = obj.fontName;
        fontSize = obj.fontSize;
        bold = obj.isBold;
        italic = obj.isItalic;
      }
    }

    state = state.copyWith(
      selectedObjectIds: newSelection,
      currentTextColor: textColor,
      currentStrokeColor: strokeColor,
      currentFillColor: fillColor,
      currentStrokeWidth: strokeWidth,
      currentFontName: fontName,
      currentFontSize: fontSize,
      currentBold: bold,
      currentItalic: italic,
    );
  }

  /// Clears active object selection.
  void clearSelection() {
    state = state.copyWith(
      selectedObjectIds: const {},
      clearActiveEditingObjectId: true,
    );
  }

  /// Sets or clears the hovered object ID for visual feedback.
  void setHoveredObject(String? objectId) {
    state = state.copyWith(
      hoveredObjectId: objectId,
      clearHoveredObjectId: objectId == null,
    );
  }

  /// Activates direct inline text editing on a text object.
  void startInlineTextEdit(String objectId) {
    final obj = _findObject(objectId);
    if (obj is PdfTextContentObject) {
      state = state.copyWith(
        activeEditingObjectId: objectId,
        selectedObjectIds: {objectId},
      );
    }
  }

  /// Commits inline text changes directly to the content object.
  void commitInlineTextEdit(String objectId, String newText) {
    final obj = _findObject(objectId);
    if (obj is PdfTextContentObject && obj.text != newText) {
      final op = ModifyTextOperation(
        objectId: objectId,
        pageIndex: obj.pageIndex,
        oldText: obj.text,
        newText: newText,
      );
      _executeOperation(op);
    }
    state = state.copyWith(clearActiveEditingObjectId: true);
  }

  /// Moves selected content object by PDF coordinate delta.
  void moveSelectedObject(double deltaPdfX, double deltaPdfY) {
    final obj = state.primarySelectedObject;
    if (obj == null) return;

    final newBounds = Rect.fromLTRB(
      obj.bounds.left + deltaPdfX,
      obj.bounds.bottom + deltaPdfY,
      obj.bounds.right + deltaPdfX,
      obj.bounds.top + deltaPdfY,
    );

    final op = MoveObjectOperation(
      objectId: obj.id,
      pageIndex: obj.pageIndex,
      oldBounds: obj.bounds,
      newBounds: newBounds,
      deltaX: deltaPdfX,
      deltaY: deltaPdfY,
    );
    _executeOperation(op);
  }

  /// Resizes selected content object.
  void resizeSelectedObject(Rect newPdfBounds) {
    final obj = state.primarySelectedObject;
    if (obj == null) return;

    final op = ResizeObjectOperation(
      objectId: obj.id,
      pageIndex: obj.pageIndex,
      oldBounds: obj.bounds,
      newBounds: newPdfBounds,
    );
    _executeOperation(op);
  }

  /// Updates styling properties of the selected text object.
  void updateSelectedTextStyle({
    String? fontName,
    double? fontSize,
    bool? bold,
    bool? italic,
    Color? color,
  }) {
    final obj = state.primarySelectedObject;
    if (obj is PdfTextContentObject) {
      final op = StyleObjectOperation(
        objectId: obj.id,
        pageIndex: obj.pageIndex,
        oldFontName: obj.fontName,
        newFontName: fontName ?? obj.fontName,
        oldFontSize: obj.fontSize,
        newFontSize: fontSize ?? obj.fontSize,
        oldBold: obj.isBold,
        newBold: bold ?? obj.isBold,
        oldItalic: obj.isItalic,
        newItalic: italic ?? obj.isItalic,
        oldFillColor: obj.fillColor,
        newFillColor: color ?? obj.fillColor,
      );
      _executeOperation(op);

      state = state.copyWith(
        currentFontName: fontName ?? state.currentFontName,
        currentFontSize: fontSize ?? state.currentFontSize,
        currentBold: bold ?? state.currentBold,
        currentItalic: italic ?? state.currentItalic,
        currentTextColor: color ?? state.currentTextColor,
      );
    }
  }

  /// Updates vector stroke/fill properties of the selected path.
  void updateSelectedShapeStyle({
    Color? strokeColor,
    Color? fillColor,
    double? strokeWidth,
  }) {
    final obj = state.primarySelectedObject;
    if (obj is PdfPathContentObject) {
      final op = StyleObjectOperation(
        objectId: obj.id,
        pageIndex: obj.pageIndex,
        oldStrokeColor: obj.strokeColor,
        newStrokeColor: strokeColor ?? obj.strokeColor,
        oldFillColor: obj.fillColor,
        newFillColor: fillColor ?? obj.fillColor,
        oldStrokeWidth: obj.strokeWidth,
        newStrokeWidth: strokeWidth ?? obj.strokeWidth,
      );
      _executeOperation(op);

      state = state.copyWith(
        currentStrokeColor: strokeColor ?? state.currentStrokeColor,
        currentFillColor: fillColor ?? state.currentFillColor,
        currentStrokeWidth: strokeWidth ?? state.currentStrokeWidth,
      );
    }
  }

  /// Inserts a new native text object into the page.
  void addNewText({
    required int pageIndex,
    required Rect bounds,
    required String text,
  }) {
    final newId = 'new_text_${_uuid.v4()}';
    final newTextObj = PdfTextContentObject(
      id: newId,
      pageIndex: pageIndex,
      objectIndex: -1,
      bounds: bounds,
      text: text,
      fontName: state.currentFontName,
      fontSize: state.currentFontSize,
      isBold: state.currentBold,
      isItalic: state.currentItalic,
      fillColor: state.currentTextColor,
      isNew: true,
    );

    final op = InsertObjectOperation(object: newTextObj);
    _executeOperation(op);
    selectObject(newId);
  }

  /// Inserts a new native vector path or shape into the page.
  void addNewShape({
    required int pageIndex,
    required VectorShapeType shapeType,
    required Rect bounds,
    required List<Offset> points,
  }) {
    final newId = 'new_path_${_uuid.v4()}';
    final newPathObj = PdfPathContentObject(
      id: newId,
      pageIndex: pageIndex,
      objectIndex: -1,
      bounds: bounds,
      shapeType: shapeType,
      points: points,
      hasStroke: true,
      hasFill: state.currentFillColor.alpha > 0,
      strokeColor: state.currentStrokeColor,
      fillColor: state.currentFillColor,
      strokeWidth: state.currentStrokeWidth,
      isNew: true,
    );

    final op = InsertObjectOperation(object: newPathObj);
    _executeOperation(op);
    selectObject(newId);
  }

  /// Inserts a new image object into the page.
  void addNewImage({
    required int pageIndex,
    required Rect bounds,
    required String imagePath,
  }) {
    final newId = 'new_img_${_uuid.v4()}';
    final newImgObj = PdfImageContentObject(
      id: newId,
      pageIndex: pageIndex,
      objectIndex: -1,
      bounds: bounds,
      localImagePath: imagePath,
      isNew: true,
    );

    final op = InsertObjectOperation(object: newImgObj);
    _executeOperation(op);
    selectObject(newId);
  }

  /// Deletes the currently selected object.
  void deleteSelected() {
    final obj = state.primarySelectedObject;
    if (obj == null) return;

    final op = DeleteObjectOperation(deletedObject: obj);
    _executeOperation(op);
    clearSelection();
  }

  /// Duplicates the currently selected object with a slight offset.
  void duplicateSelected() {
    final obj = state.primarySelectedObject;
    if (obj == null) return;

    final offsetBounds = Rect.fromLTRB(
      obj.bounds.left + 20,
      obj.bounds.bottom - 20,
      obj.bounds.right + 20,
      obj.bounds.top - 20,
    );

    final newId = 'dup_${_uuid.v4()}';
    PdfContentObject duplicated;
    if (obj is PdfTextContentObject) {
      duplicated = obj.copyWith(
        id: newId,
        objectIndex: -1,
        bounds: offsetBounds,
        isNew: true,
      );
    } else if (obj is PdfPathContentObject) {
      final shiftedPoints = obj.points
          .map((pt) => Offset(pt.dx + 20, pt.dy - 20))
          .toList();
      duplicated = obj.copyWith(
        id: newId,
        objectIndex: -1,
        bounds: offsetBounds,
        points: shiftedPoints,
        isNew: true,
      );
    } else if (obj is PdfImageContentObject) {
      duplicated = obj.copyWith(
        id: newId,
        objectIndex: -1,
        bounds: offsetBounds,
        isNew: true,
      );
    } else {
      return;
    }

    final op = InsertObjectOperation(object: duplicated);
    _executeOperation(op);
    selectObject(newId);
  }

  /// Undoes the last committed edit transaction.
  void undo() {
    final tx = _history.popUndo();
    if (tx == null) return;

    // Apply revert in reverse order
    for (final op in tx.operations.reversed) {
      _applyRevert(op);
      _pendingOperations.remove(op);
    }

    state = state.copyWith(
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      isDirty: _pendingOperations.isNotEmpty,
    );
  }

  /// Redoes the previously undone transaction.
  void redo() {
    final tx = _history.popRedo();
    if (tx == null) return;

    for (final op in tx.operations) {
      _applyForward(op);
      _pendingOperations.add(op);
    }

    state = state.copyWith(
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      isDirty: _pendingOperations.isNotEmpty,
    );
  }

  /// Persists all modifications directly into the authentic PDF document.
  Future<String> save({
    String? outputPath,
    bool overwriteOriginal = false,
  }) async {
    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final effectiveTarget = outputPath ?? state.documentPath;
      final savedPath = await _saveService.saveDocument(
        sourcePath: state.documentPath,
        targetPath: effectiveTarget,
        modifiedPagesObjects: state.extractedObjectsByPage,
        operations: _pendingOperations,
        overwriteOriginal: overwriteOriginal || (outputPath == null),
      );

      _pendingOperations.clear();
      _history.clear();

      state = state.copyWith(
        documentPath: savedPath,
        isSaving: false,
        isDirty: false,
        canUndo: false,
        canRedo: false,
      );

      return savedPath;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save PDF content: $e',
      );
      rethrow;
    }
  }

  void _executeOperation(PdfEditOperation op) {
    _applyForward(op);
    _pendingOperations.add(op);

    final tx = PdfEditTransaction(
      id: _uuid.v4(),
      name: op.description,
      operations: [op],
    );
    _history.pushTransaction(tx);

    state = state.copyWith(
      isDirty: true,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
  }

  void _applyForward(PdfEditOperation op) {
    final pageIdx = op.pageIndex;
    final currentObjs = List<PdfContentObject>.from(
      state.extractedObjectsByPage[pageIdx] ?? [],
    );

    if (op is InsertObjectOperation) {
      currentObjs.add(op.object);
    } else {
      final idx = currentObjs.indexWhere((o) => o.id == op.objectId);
      if (idx != -1) {
        currentObjs[idx] = op.apply(currentObjs[idx]);
      }
    }

    final updated = Map<int, List<PdfContentObject>>.from(
      state.extractedObjectsByPage,
    )..[pageIdx] = currentObjs;

    state = state.copyWith(extractedObjectsByPage: updated);
  }

  void _applyRevert(PdfEditOperation op) {
    final pageIdx = op.pageIndex;
    final currentObjs = List<PdfContentObject>.from(
      state.extractedObjectsByPage[pageIdx] ?? [],
    );

    if (op is InsertObjectOperation) {
      currentObjs.removeWhere((o) => o.id == op.objectId);
    } else {
      final idx = currentObjs.indexWhere((o) => o.id == op.objectId);
      if (idx != -1) {
        currentObjs[idx] = op.revert(currentObjs[idx]);
      }
    }

    final updated = Map<int, List<PdfContentObject>>.from(
      state.extractedObjectsByPage,
    )..[pageIdx] = currentObjs;

    state = state.copyWith(extractedObjectsByPage: updated);
  }

  PdfContentObject? _findObject(String id) {
    for (final pageObjs in state.extractedObjectsByPage.values) {
      for (final obj in pageObjs) {
        if (obj.id == id && !obj.isDeleted) return obj;
      }
    }
    return null;
  }
}
