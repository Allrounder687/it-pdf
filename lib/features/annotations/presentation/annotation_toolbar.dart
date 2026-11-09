import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/annotation_model.dart';
import '../domain/annotation_notifier.dart';

/// Floating or docked annotation toolbar for selecting drawing tools, shapes, colors and undo/redo.
class AnnotationToolbar extends ConsumerWidget {
  final String documentId;

  const AnnotationToolbar({super.key, required this.documentId});

  static const List<Color> _palette = [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFFFF5722), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF000000), // Black
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(annotationNotifierProvider(documentId));
    final notifier = ref.read(annotationNotifierProvider(documentId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pointer / Navigation mode
              IconButton(
                icon: Icon(
                  Icons.pan_tool_outlined,
                  color: state.activeTool == AnnotationTool.none
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Navigation Mode',
                onPressed: () => notifier.setActiveTool(AnnotationTool.none),
              ),
              const VerticalDivider(width: 12),

              // Pen
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: state.activeTool == AnnotationTool.pen
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Pen',
                onPressed: () => notifier.setActiveTool(AnnotationTool.pen),
              ),

              // Highlighter
              IconButton(
                icon: Icon(
                  Icons.border_color_outlined,
                  color: state.activeTool == AnnotationTool.highlighter
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Highlighter',
                onPressed: () =>
                    notifier.setActiveTool(AnnotationTool.highlighter),
              ),

              // Underline
              IconButton(
                icon: Icon(
                  Icons.format_underlined,
                  color: state.activeTool == AnnotationTool.underline
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Underline',
                onPressed: () =>
                    notifier.setActiveTool(AnnotationTool.underline),
              ),

              // Strikethrough
              IconButton(
                icon: Icon(
                  Icons.format_strikethrough,
                  color: state.activeTool == AnnotationTool.strikethrough
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Strikethrough',
                onPressed: () =>
                    notifier.setActiveTool(AnnotationTool.strikethrough),
              ),

              // Arrow
              IconButton(
                icon: Icon(
                  Icons.arrow_right_alt,
                  color: state.activeTool == AnnotationTool.arrow
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Arrow',
                onPressed: () => notifier.setActiveTool(AnnotationTool.arrow),
              ),

              // Rectangle
              IconButton(
                icon: Icon(
                  Icons.crop_square,
                  color: state.activeTool == AnnotationTool.rectangle
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Rectangle',
                onPressed: () =>
                    notifier.setActiveTool(AnnotationTool.rectangle),
              ),

              // Circle
              IconButton(
                icon: Icon(
                  Icons.circle_outlined,
                  color: state.activeTool == AnnotationTool.circle
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Circle',
                onPressed: () => notifier.setActiveTool(AnnotationTool.circle),
              ),

              // Sticky Note
              IconButton(
                icon: Icon(
                  Icons.sticky_note_2_outlined,
                  color: state.activeTool == AnnotationTool.stickyNote
                      ? Colors.blue
                      : null,
                  size: 20,
                ),
                tooltip: 'Sticky Note',
                onPressed: () =>
                    notifier.setActiveTool(AnnotationTool.stickyNote),
              ),

              // Eraser
              IconButton(
                icon: Icon(
                  Icons.auto_fix_normal_outlined,
                  color: state.activeTool == AnnotationTool.eraser
                      ? Colors.redAccent
                      : null,
                  size: 20,
                ),
                tooltip: 'Eraser',
                onPressed: () => notifier.setActiveTool(AnnotationTool.eraser),
              ),

              const VerticalDivider(width: 12),

              // Color Palette Selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _palette.map((color) {
                  final isSelected =
                      state.currentColor.toARGB32() == color.toARGB32();
                  return InkWell(
                    onTap: () => notifier.setColor(color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade400,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const VerticalDivider(width: 12),

              // Undo
              IconButton(
                icon: const Icon(Icons.undo, size: 20),
                tooltip: 'Undo',
                onPressed: state.canUndo ? () => notifier.undo() : null,
              ),

              // Redo
              IconButton(
                icon: const Icon(Icons.redo, size: 20),
                tooltip: 'Redo',
                onPressed: state.canRedo ? () => notifier.redo() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
