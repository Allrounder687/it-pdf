import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/editor_notifier.dart';
import '../domain/editor_state.dart';
import '../domain/pdf_content_object.dart';

/// Overlay widget mounted on each PDF page in Edit Mode.
/// Provides direct click-to-select, drag-to-move, handle resizing,
/// inline text editing, and point-and-click shape insertion.
class EditorCanvasOverlay extends ConsumerStatefulWidget {
  final String documentId;
  final String documentPath;
  final int pageIndex; // 0-based
  final Size pageSize; // PDF points
  final Size renderSize; // Flutter screen pixels

  const EditorCanvasOverlay({
    super.key,
    required this.documentId,
    required this.documentPath,
    required this.pageIndex,
    required this.pageSize,
    required this.renderSize,
  });

  @override
  ConsumerState<EditorCanvasOverlay> createState() =>
      _EditorCanvasOverlayState();
}

class _EditorCanvasOverlayState extends ConsumerState<EditorCanvasOverlay> {
  Offset? _creationStart;
  Offset? _creationCurrent;
  Offset? _dragStartScreen;
  Rect? _initialObjectBounds;
  TransformHandle _activeHandle = TransformHandle.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final params = EditorNotifierParams(
        documentId: widget.documentId,
        documentPath: widget.documentPath,
      );
      ref
          .read(editorNotifierProvider(params).notifier)
          .loadPageObjects(widget.pageIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = EditorNotifierParams(
      documentId: widget.documentId,
      documentPath: widget.documentPath,
    );
    final editorState = ref.watch(editorNotifierProvider(params));
    final notifier = ref.read(editorNotifierProvider(params).notifier);

    if (editorState.workspaceMode != WorkspaceMode.edit) {
      return const SizedBox.shrink();
    }

    final pageObjects = editorState.objectsForPage(widget.pageIndex);
    final primarySelected = editorState.primarySelectedObject;
    final isSelectedOnThisPage =
        primarySelected != null &&
        primarySelected.pageIndex == widget.pageIndex;
    final isShapeTool =
        editorState.activeTool == EditorTool.addLine ||
        editorState.activeTool == EditorTool.addArrow ||
        editorState.activeTool == EditorTool.addRectangle ||
        editorState.activeTool == EditorTool.addEllipse;

    return Positioned.fill(
      child: MouseRegion(
        cursor: _getCursorForTool(editorState.activeTool),
        child: GestureDetector(
          behavior:
              (isShapeTool ||
                  isSelectedOnThisPage ||
                  editorState.activeTool == EditorTool.addText)
              ? HitTestBehavior.opaque
              : HitTestBehavior.translucent,
          onTapDown: (details) {
            final tapPos = details.localPosition;
            if (editorState.activeTool == EditorTool.addText) {
              // Insert new text box at tap position
              final pdfPt = _screenToPdfPoint(tapPos);
              final pdfBounds = Rect.fromLTWH(pdfPt.dx, pdfPt.dy, 140, 24);
              notifier.addNewText(
                pageIndex: widget.pageIndex,
                bounds: pdfBounds,
                text: 'New Text',
              );
              notifier.setActiveTool(EditorTool.select);
            } else if (editorState.activeTool == EditorTool.select ||
                editorState.activeTool == EditorTool.editText) {
              // Hit test existing objects (reverse order for z-index)
              PdfContentObject? hitObj;
              for (final obj in pageObjects.reversed) {
                final screenRect = obj.toScreenRect(
                  widget.pageSize,
                  widget.renderSize,
                );
                if (screenRect.inflate(4).contains(tapPos)) {
                  hitObj = obj;
                  break;
                }
              }

              if (hitObj != null) {
                notifier.selectObject(hitObj.id);
              } else {
                notifier.clearSelection();
              }
            }
          },
          onPanStart: (details) {
            _creationStart = details.localPosition;
            _creationCurrent = details.localPosition;
            _dragStartScreen = details.localPosition;

            if (isSelectedOnThisPage && primarySelected != null) {
              _initialObjectBounds = primarySelected.bounds;
              _activeHandle = _hitTestHandle(
                details.localPosition,
                primarySelected.toScreenRect(
                  widget.pageSize,
                  widget.renderSize,
                ),
              );
            }
          },
          onPanUpdate: (details) {
            setState(() {
              _creationCurrent = details.localPosition;
            });

            if (isSelectedOnThisPage &&
                primarySelected != null &&
                _dragStartScreen != null &&
                _initialObjectBounds != null) {
              final deltaScreen = details.localPosition - _dragStartScreen!;
              final scaleX = widget.pageSize.width / widget.renderSize.width;
              final scaleY = widget.pageSize.height / widget.renderSize.height;

              if (_activeHandle == TransformHandle.body) {
                // Moving object
                final deltaPdfX = deltaScreen.dx * scaleX;
                final deltaPdfY = -deltaScreen.dy * scaleY;
                final newPdfBounds = Rect.fromLTRB(
                  _initialObjectBounds!.left + deltaPdfX,
                  _initialObjectBounds!.bottom + deltaPdfY,
                  _initialObjectBounds!.right + deltaPdfX,
                  _initialObjectBounds!.top + deltaPdfY,
                );
                notifier.resizeSelectedObject(newPdfBounds);
              }
            }
          },
          onPanEnd: (details) {
            if (_creationStart != null && _creationCurrent != null) {
              final screenRect = Rect.fromPoints(
                _creationStart!,
                _creationCurrent!,
              );
              if (screenRect.width > 5 || screenRect.height > 5) {
                final pdfRect = PdfContentObject.fromScreenRect(
                  screenRect,
                  widget.pageSize,
                  widget.renderSize,
                );

                if (editorState.activeTool == EditorTool.addLine) {
                  final pt1 = _screenToPdfPoint(_creationStart!);
                  final pt2 = _screenToPdfPoint(_creationCurrent!);
                  notifier.addNewShape(
                    pageIndex: widget.pageIndex,
                    shapeType: VectorShapeType.line,
                    bounds: pdfRect,
                    points: [pt1, pt2],
                  );
                  notifier.setActiveTool(EditorTool.select);
                } else if (editorState.activeTool == EditorTool.addArrow) {
                  final pt1 = _screenToPdfPoint(_creationStart!);
                  final pt2 = _screenToPdfPoint(_creationCurrent!);
                  notifier.addNewShape(
                    pageIndex: widget.pageIndex,
                    shapeType: VectorShapeType.arrow,
                    bounds: pdfRect,
                    points: [pt1, pt2],
                  );
                  notifier.setActiveTool(EditorTool.select);
                } else if (editorState.activeTool == EditorTool.addRectangle) {
                  notifier.addNewShape(
                    pageIndex: widget.pageIndex,
                    shapeType: VectorShapeType.rectangle,
                    bounds: pdfRect,
                    points: [
                      Offset(pdfRect.left, pdfRect.bottom),
                      Offset(pdfRect.right, pdfRect.top),
                    ],
                  );
                  notifier.setActiveTool(EditorTool.select);
                }
              }
            }

            _creationStart = null;
            _creationCurrent = null;
            _dragStartScreen = null;
            _initialObjectBounds = null;
            _activeHandle = TransformHandle.none;
          },
          child: Stack(
            children: [
              // 1. Render bounding indicators for all page objects
              for (final obj in pageObjects)
                _buildObjectIndicator(context, notifier, editorState, obj),

              // 2. Render primary selection bounding box & handles
              if (isSelectedOnThisPage && primarySelected != null)
                _buildSelectionBox(context, notifier, primarySelected),

              // 3. Render active creation drag preview
              if (_creationStart != null && _creationCurrent != null)
                _buildCreationPreview(editorState.activeTool),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectIndicator(
    BuildContext context,
    EditorNotifier notifier,
    EditorState state,
    PdfContentObject obj,
  ) {
    final screenRect = obj.toScreenRect(widget.pageSize, widget.renderSize);
    final isSelected = state.selectedObjectIds.contains(obj.id);
    final isHovered = state.hoveredObjectId == obj.id;
    final isInlineEditing = state.activeEditingObjectId == obj.id;

    if (isInlineEditing && obj is PdfTextContentObject) {
      // In-place text editing field
      return Positioned(
        left: screenRect.left,
        top: screenRect.top - 2,
        width: screenRect.width.clamp(80.0, 600.0),
        height: screenRect.height.clamp(24.0, 300.0),
        child: Material(
          color: Colors.transparent,
          child: TextFormField(
            initialValue: obj.text,
            autofocus: true,
            style: TextStyle(
              fontSize:
                  (obj.fontSize *
                  (widget.renderSize.width / widget.pageSize.width)),
              color: obj.fillColor,
              fontWeight: obj.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: obj.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(
                  color: Color(0xFF2196F3),
                  width: 1.5,
                ),
              ),
              fillColor: Colors.white.withValues(alpha: 0.9),
              filled: true,
            ),
            onFieldSubmitted: (newVal) {
              notifier.commitInlineTextEdit(obj.id, newVal);
            },
          ),
        ),
      );
    }

    return Positioned(
      left: screenRect.left,
      top: screenRect.top,
      width: screenRect.width,
      height: screenRect.height,
      child: MouseRegion(
        onEnter: (_) => notifier.setHoveredObject(obj.id),
        onExit: (_) => notifier.setHoveredObject(null),
        child: GestureDetector(
          onDoubleTap: () {
            if (obj is PdfTextContentObject) {
              notifier.startInlineTextEdit(obj.id);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1976D2)
                    : (isHovered
                          ? const Color(0xFF90CAF9)
                          : Colors.transparent),
                width: isSelected ? 1.5 : 1,
              ),
              color: isHovered && !isSelected
                  ? const Color(0xFF2196F3).withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBox(
    BuildContext context,
    EditorNotifier notifier,
    PdfContentObject obj,
  ) {
    final screenRect = obj.toScreenRect(widget.pageSize, widget.renderSize);
    const handleSize = 7.0;

    return Positioned(
      left: screenRect.left - handleSize / 2,
      top: screenRect.top - handleSize / 2,
      width: screenRect.width + handleSize,
      height: screenRect.height + handleSize,
      child: IgnorePointer(
        child: Stack(
          children: [
            // Border box
            Positioned(
              left: handleSize / 2,
              top: handleSize / 2,
              width: screenRect.width,
              height: screenRect.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF1976D2),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Handles: Top-Left, Top-Right, Bottom-Left, Bottom-Right
            _buildHandleCircle(0, 0, handleSize),
            _buildHandleCircle(screenRect.width, 0, handleSize),
            _buildHandleCircle(0, screenRect.height, handleSize),
            _buildHandleCircle(screenRect.width, screenRect.height, handleSize),
          ],
        ),
      ),
    );
  }

  Widget _buildHandleCircle(double x, double y, double size) {
    return Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          border: Border.all(color: const Color(0xFF1976D2), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCreationPreview(EditorTool tool) {
    final rect = Rect.fromPoints(_creationStart!, _creationCurrent!);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF1976D2),
              style: BorderStyle.solid,
              width: 1.5,
            ),
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  TransformHandle _hitTestHandle(Offset pos, Rect rect) {
    const threshold = 12.0;
    if ((pos - rect.topLeft).distance <= threshold)
      return TransformHandle.topLeft;
    if ((pos - rect.topRight).distance <= threshold)
      return TransformHandle.topRight;
    if ((pos - rect.bottomLeft).distance <= threshold)
      return TransformHandle.bottomLeft;
    if ((pos - rect.bottomRight).distance <= threshold)
      return TransformHandle.bottomRight;
    if (rect.contains(pos)) return TransformHandle.body;
    return TransformHandle.none;
  }

  Offset _screenToPdfPoint(Offset screenPos) {
    final scaleX = widget.pageSize.width / widget.renderSize.width;
    final scaleY = widget.pageSize.height / widget.renderSize.height;
    final pdfX = screenPos.dx * scaleX;
    final pdfY = widget.pageSize.height - (screenPos.dy * scaleY);
    return Offset(pdfX, pdfY);
  }

  MouseCursor _getCursorForTool(EditorTool tool) {
    switch (tool) {
      case EditorTool.select:
        return SystemMouseCursors.basic;
      case EditorTool.editText:
      case EditorTool.editParagraph:
      case EditorTool.addText:
        return SystemMouseCursors.text;
      case EditorTool.addLine:
      case EditorTool.addArrow:
      case EditorTool.addRectangle:
      case EditorTool.addEllipse:
        return SystemMouseCursors.precise;
      case EditorTool.addImage:
        return SystemMouseCursors.click;
      case EditorTool.deleteObject:
        return SystemMouseCursors.forbidden;
    }
  }
}
