import 'package:flutter/material.dart';
import 'pdf_content_object.dart';

/// Top-level operating mode of the document workspace.
enum WorkspaceMode { read, annotate, edit, forms }

/// Tools available exclusively within genuine PDF Content Edit mode.
enum EditorTool {
  select,
  editText,
  editParagraph,
  addText,
  addLine,
  addArrow,
  addRectangle,
  addEllipse,
  addImage,
  deleteObject,
}

/// Transform handle currently being interacted with.
enum TransformHandle {
  none,
  topLeft,
  topCenter,
  topRight,
  centerRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  centerLeft,
  body,
}

/// State of the PDF Content Editor subsystem for a document.
class EditorState {
  final String documentId;
  final String documentPath;
  final WorkspaceMode workspaceMode;
  final EditorTool activeTool;
  final Set<String> selectedObjectIds;
  final String? hoveredObjectId;
  final String? activeEditingObjectId;
  final Map<int, List<PdfContentObject>> extractedObjectsByPage;
  final Map<int, List<PdfParagraphBlock>> paragraphsByPage;
  final bool isDirty;
  final bool canUndo;
  final bool canRedo;
  final bool isLoading;
  final bool isSaving;
  final bool isPropertiesPanelOpen;
  final String? errorMessage;

  bool get hasUnsavedChanges => isDirty;

  // Active style presets for new/selected objects
  final Color currentTextColor;
  final Color currentStrokeColor;
  final Color currentFillColor;
  final double currentStrokeWidth;
  final String currentFontName;
  final double currentFontSize;
  final bool currentBold;
  final bool currentItalic;
  final TextAlign currentTextAlign;

  const EditorState({
    required this.documentId,
    required this.documentPath,
    this.workspaceMode = WorkspaceMode.read,
    this.activeTool = EditorTool.select,
    this.selectedObjectIds = const {},
    this.hoveredObjectId,
    this.activeEditingObjectId,
    this.extractedObjectsByPage = const {},
    this.paragraphsByPage = const {},
    this.isDirty = false,
    this.canUndo = false,
    this.canRedo = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isPropertiesPanelOpen = true,
    this.errorMessage,
    this.currentTextColor = Colors.black,
    this.currentStrokeColor = const Color(0xFF2196F3),
    this.currentFillColor = Colors.transparent,
    this.currentStrokeWidth = 2.0,
    this.currentFontName = 'Helvetica',
    this.currentFontSize = 14.0,
    this.currentBold = false,
    this.currentItalic = false,
    this.currentTextAlign = TextAlign.left,
  });

  PdfContentObject? get primarySelectedObject {
    if (selectedObjectIds.isEmpty) return null;
    final firstId = selectedObjectIds.first;
    for (final pageObjs in extractedObjectsByPage.values) {
      for (final obj in pageObjs) {
        if (obj.id == firstId && !obj.isDeleted) return obj;
      }
    }
    return null;
  }

  List<PdfContentObject> objectsForPage(int pageIndex) {
    return extractedObjectsByPage[pageIndex]
            ?.where((o) => !o.isDeleted)
            .toList() ??
        const [];
  }

  EditorState copyWith({
    String? documentId,
    String? documentPath,
    WorkspaceMode? workspaceMode,
    EditorTool? activeTool,
    Set<String>? selectedObjectIds,
    String? hoveredObjectId,
    bool clearHoveredObjectId = false,
    String? activeEditingObjectId,
    bool clearActiveEditingObjectId = false,
    Map<int, List<PdfContentObject>>? extractedObjectsByPage,
    Map<int, List<PdfParagraphBlock>>? paragraphsByPage,
    bool? isDirty,
    bool? canUndo,
    bool? canRedo,
    bool? isLoading,
    bool? isSaving,
    bool? isPropertiesPanelOpen,
    String? errorMessage,
    bool clearErrorMessage = false,
    Color? currentTextColor,
    Color? currentStrokeColor,
    Color? currentFillColor,
    double? currentStrokeWidth,
    String? currentFontName,
    double? currentFontSize,
    bool? currentBold,
    bool? currentItalic,
    TextAlign? currentTextAlign,
  }) {
    return EditorState(
      documentId: documentId ?? this.documentId,
      documentPath: documentPath ?? this.documentPath,
      workspaceMode: workspaceMode ?? this.workspaceMode,
      activeTool: activeTool ?? this.activeTool,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      hoveredObjectId: clearHoveredObjectId
          ? null
          : (hoveredObjectId ?? this.hoveredObjectId),
      activeEditingObjectId: clearActiveEditingObjectId
          ? null
          : (activeEditingObjectId ?? this.activeEditingObjectId),
      extractedObjectsByPage:
          extractedObjectsByPage ?? this.extractedObjectsByPage,
      paragraphsByPage: paragraphsByPage ?? this.paragraphsByPage,
      isDirty: isDirty ?? this.isDirty,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isPropertiesPanelOpen:
          isPropertiesPanelOpen ?? this.isPropertiesPanelOpen,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      currentTextColor: currentTextColor ?? this.currentTextColor,
      currentStrokeColor: currentStrokeColor ?? this.currentStrokeColor,
      currentFillColor: currentFillColor ?? this.currentFillColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      currentFontName: currentFontName ?? this.currentFontName,
      currentFontSize: currentFontSize ?? this.currentFontSize,
      currentBold: currentBold ?? this.currentBold,
      currentItalic: currentItalic ?? this.currentItalic,
      currentTextAlign: currentTextAlign ?? this.currentTextAlign,
    );
  }
}
