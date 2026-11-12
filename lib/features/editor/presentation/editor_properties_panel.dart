import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../data/pdf_font_manager.dart';
import '../domain/editor_notifier.dart';
import '../domain/editor_state.dart';
import '../domain/pdf_content_object.dart';

/// Professional properties panel for inspecting and modifying PDF page objects.
class EditorPropertiesPanel extends ConsumerWidget {
  final String documentId;
  final String documentPath;
  final VoidCallback onClose;

  const EditorPropertiesPanel({
    super.key,
    required this.documentId,
    required this.documentPath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = EditorNotifierParams(
      documentId: documentId,
      documentPath: documentPath,
    );
    final editorState = ref.watch(editorNotifierProvider(params));
    final notifier = ref.read(editorNotifierProvider(params).notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final accentColor = isDark
        ? AppTheme.primaryBlueDark
        : AppTheme.primaryBlue;

    final selectedObj = editorState.primarySelectedObject;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedObj != null
                      ? '${selectedObj.type.name.toUpperCase()} PROPERTIES'
                      : 'OBJECT PROPERTIES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: textSecondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  color: textSecondary,
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (selectedObj is PdfTextContentObject) ...[
                  _buildTextProperties(
                    context,
                    notifier,
                    selectedObj,
                    textPrimary,
                    textSecondary,
                    borderColor,
                    accentColor,
                  ),
                ] else if (selectedObj is PdfPathContentObject) ...[
                  _buildPathProperties(
                    context,
                    notifier,
                    selectedObj,
                    textPrimary,
                    textSecondary,
                    borderColor,
                    accentColor,
                  ),
                ] else if (selectedObj is PdfImageContentObject) ...[
                  _buildImageProperties(
                    context,
                    notifier,
                    selectedObj,
                    textPrimary,
                    textSecondary,
                    borderColor,
                    accentColor,
                  ),
                ] else ...[
                  // No object selected: show instructions & preset defaults
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 36,
                            color: textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Click any text, line or image\non the page to edit its properties.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextProperties(
    BuildContext context,
    EditorNotifier notifier,
    PdfTextContentObject obj,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text Content
        Text(
          'Text Content',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('text_edit_${obj.id}_${obj.text}'),
          initialValue: obj.text,
          maxLines: 3,
          style: TextStyle(fontSize: 12, color: textPrimary),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: borderColor),
            ),
            contentPadding: const EdgeInsets.all(8),
            isDense: true,
          ),
          onFieldSubmitted: (val) {
            notifier.commitInlineTextEdit(obj.id, val);
          },
        ),
        const SizedBox(height: 14),

        // Font Family
        Text(
          'Font Family',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: PdfFontManager.availableEditorFontFamilies.firstWhere(
                (f) => obj.fontName.toLowerCase().contains(f.toLowerCase()),
                orElse: () => 'Helvetica',
              ),
              isExpanded: true,
              style: TextStyle(fontSize: 12, color: textPrimary),
              items: PdfFontManager.availableEditorFontFamilies.map((f) {
                return DropdownMenuItem(value: f, child: Text(f));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.updateSelectedTextStyle(fontName: val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Font Size & Style
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 14),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          notifier.updateSelectedTextStyle(
                            fontSize: (obj.fontSize - 1).clamp(6.0, 120.0),
                          );
                        },
                      ),
                      Text(
                        '${obj.fontSize.round()} pt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 14),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          notifier.updateSelectedTextStyle(
                            fontSize: (obj.fontSize + 1).clamp(6.0, 120.0),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bold / Italic Toggles
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.format_bold_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  isSelected: obj.isBold,
                  color: obj.isBold ? accentColor : textSecondary,
                  onPressed: () {
                    notifier.updateSelectedTextStyle(bold: !obj.isBold);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  isSelected: obj.isItalic,
                  color: obj.isItalic ? accentColor : textSecondary,
                  onPressed: () {
                    notifier.updateSelectedTextStyle(italic: !obj.isItalic);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Color Picker
        Text(
          'Text Color',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              [
                Colors.black,
                Colors.white,
                const Color(0xFF1976D2), // Blue
                const Color(0xFFD32F2F), // Red
                const Color(0xFF388E3C), // Green
                const Color(0xFFF57C00), // Orange
                const Color(0xFF7B1FA2), // Purple
              ].map((color) {
                final isSelected = obj.fillColor == color;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => notifier.updateSelectedTextStyle(color: color),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accentColor : borderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 16),

        // Geometry info
        Text(
          'Position & Dimensions',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'X: ${obj.bounds.left.round()} pt   Y: ${obj.bounds.bottom.round()} pt\nW: ${obj.bounds.width.round()} pt   H: ${obj.bounds.height.round()} pt',
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildPathProperties(
    BuildContext context,
    EditorNotifier notifier,
    PdfPathContentObject obj,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vector Shape: ${obj.shapeType.name.toUpperCase()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // Stroke Width
        Text(
          'Stroke Width',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                notifier.updateSelectedShapeStyle(
                  strokeWidth: (obj.strokeWidth - 0.5).clamp(0.5, 20.0),
                );
              },
            ),
            Text(
              '${obj.strokeWidth.toStringAsFixed(1)} pt',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                notifier.updateSelectedShapeStyle(
                  strokeWidth: (obj.strokeWidth + 0.5).clamp(0.5, 20.0),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Stroke Color
        Text(
          'Stroke Color',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              [
                Colors.black,
                const Color(0xFF1976D2),
                const Color(0xFFD32F2F),
                const Color(0xFF388E3C),
                const Color(0xFFF57C00),
              ].map((color) {
                final isSelected = obj.strokeColor == color;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      notifier.updateSelectedShapeStyle(strokeColor: color),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accentColor : borderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 14),

        // Fill Color
        Text(
          'Fill Color',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              [
                Colors.transparent,
                Colors.white,
                const Color(0xFFE3F2FD), // Light blue
                const Color(0xFFFFEBEE), // Light red
                const Color(0xFFE8F5E9), // Light green
              ].map((color) {
                final isSelected = obj.fillColor == color;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      notifier.updateSelectedShapeStyle(fillColor: color),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color == Colors.transparent
                          ? Colors.grey.shade300
                          : color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accentColor : borderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: color == Colors.transparent
                        ? const Icon(Icons.block, size: 14, color: Colors.red)
                        : null,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageProperties(
    BuildContext context,
    EditorNotifier notifier,
    PdfImageContentObject obj,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Embedded Image',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dimensions:\nWidth: ${obj.bounds.width.round()} pt\nHeight: ${obj.bounds.height.round()} pt',
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_library_outlined, size: 16),
          label: const Text('Replace Image'),
          onPressed: () async {
            final result = await FilePicker.pickFile(type: FileType.image);
            if (result != null && result.path != null) {
              final newPath = result.path!;
              notifier.addNewImage(
                pageIndex: obj.pageIndex,
                bounds: obj.bounds,
                imagePath: newPath,
              );
              notifier.deleteSelected();
            }
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
          label: const Text(
            'Delete Image',
            style: TextStyle(color: Colors.red),
          ),
          onPressed: notifier.deleteSelected,
        ),
      ],
    );
  }
}
