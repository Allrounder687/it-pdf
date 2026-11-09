import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/annotation_model.dart';
import '../domain/annotation_notifier.dart';

/// Floating or docked annotation toolbar for selecting drawing tools, colors and undo/redo.
class AnnotationToolbar extends ConsumerWidget {
  final String documentId;

  const AnnotationToolbar({
    super.key,
    required this.documentId,
  });

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close / Pointer tool
            IconButton(
              icon: Icon(
                Icons.pan_tool_outlined,
                color: state.activeTool == AnnotationTool.none ? Colors.blue : null,
              ),
              tooltip: 'Navigation Mode',
              onPressed: () => notifier.setActiveTool(AnnotationTool.none),
            ),
            const VerticalDivider(width: 16),

            // Pen
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: state.activeTool == AnnotationTool.pen ? Colors.blue : null,
              ),
              tooltip: 'Pen',
              onPressed: () => notifier.setActiveTool(AnnotationTool.pen),
            ),

            // Highlighter
            IconButton(
              icon: Icon(
                Icons.border_color_outlined,
                color: state.activeTool == AnnotationTool.highlighter ? Colors.blue : null,
              ),
              tooltip: 'Highlighter',
              onPressed: () => notifier.setActiveTool(AnnotationTool.highlighter),
            ),

            // Shapes / Arrow
            IconButton(
              icon: Icon(
                Icons.arrow_right_alt,
                color: state.activeTool == AnnotationTool.arrow ? Colors.blue : null,
              ),
              tooltip: 'Arrow',
              onPressed: () => notifier.setActiveTool(AnnotationTool.arrow),
            ),

            const VerticalDivider(width: 16),

            // Color Palette Selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _palette.map((color) {
                final isSelected = state.currentColor.toARGB32() == color.toARGB32();
                return InkWell(
                  onTap: () => notifier.setColor(color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const VerticalDivider(width: 16),

            // Undo
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: state.canUndo ? () => notifier.undo() : null,
            ),

            // Redo
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: state.canRedo ? () => notifier.redo() : null,
            ),
          ],
        ),
      ),
    );
  }
}
