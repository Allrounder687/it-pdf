import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import 'pdf_tool_model.dart';

class ImagesToPdfTool extends PdfTool {
  const ImagesToPdfTool();

  @override
  String get id => 'images_to_pdf';

  @override
  String get title => 'Images to PDF Studio';

  @override
  String get description =>
      'Reorder photos & scans, set A4/Letter/Fit sizing, margins, and orientation.';

  @override
  IconData get icon => Icons.photo_library_outlined;

  @override
  Color get color => AppTheme.toolBlue;

  @override
  ToolCategory get category => ToolCategory.convert;

  @override
  String get badge => 'STUDIO';

  @override
  List<String> get searchKeywords => const [
    'image',
    'images',
    'jpg',
    'jpeg',
    'png',
    'photos',
    'convert',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _ImagesToPdfStudioScreen()),
    );
  }
}

enum _ImagePagePreset {
  a4('A4 Standard'),
  letter('US Letter'),
  fitImage('Fit Image Size');

  final String label;
  const _ImagePagePreset(this.label);
}

class _ImagesToPdfStudioScreen extends ConsumerStatefulWidget {
  const _ImagesToPdfStudioScreen();

  @override
  ConsumerState<_ImagesToPdfStudioScreen> createState() =>
      _ImagesToPdfStudioScreenState();
}

class _ImagesToPdfStudioScreenState
    extends ConsumerState<_ImagesToPdfStudioScreen> {
  final List<String> _imagePaths = [];
  _ImagePagePreset _preset = _ImagePagePreset.a4;
  bool _landscape = false;
  double _margin = 18.0;
  bool _isDragging = false;
  bool _isBuilding = false;

  static const _supportedExts = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'};

  Future<void> _pickImages() async {
    final picked = await ref.read(filePickerServiceProvider).pickImageFiles();
    if (picked.isNotEmpty && mounted) {
      setState(() => _imagePaths.addAll(picked));
    }
  }

  void _addDropped(List<String> paths) {
    final valid = paths.where(
      (path) => _supportedExts.contains(p.extension(path).toLowerCase()),
    );
    if (valid.isNotEmpty) {
      setState(() => _imagePaths.addAll(valid));
    }
  }

  Future<void> _buildPdf() async {
    if (_imagePaths.isEmpty) return;

    final filePicker = ref.read(filePickerServiceProvider);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: 'images_compiled.pdf',
      dialogTitle: 'Save Images PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isBuilding = true);
    try {
      final Size? fixedSize = switch (_preset) {
        _ImagePagePreset.a4 => sf.PdfPageSize.a4,
        _ImagePagePreset.letter => sf.PdfPageSize.letter,
        _ImagePagePreset.fitImage => null,
      };

      await ref
          .read(syncfusionPdfServiceProvider)
          .buildPdfFromImagesAdvanced(
            imagePaths: _imagePaths,
            outputPath: dest,
            fixedPageSize: fixedSize,
            landscape: _landscape,
            margin: _margin,
          );

      final doc = await ref
          .read(libraryNotifierProvider.notifier)
          .importFileFromPath(dest);
      if (!mounted) return;

      if (doc != null) {
        ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Built PDF from ${_imagePaths.length} images successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isBuilding = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image conversion failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Images to PDF Studio'),
        actions: [
          TextButton.icon(
            onPressed: _isBuilding ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add Images'),
          ),
          if (_imagePaths.isNotEmpty)
            TextButton(
              onPressed: _isBuilding
                  ? null
                  : () => setState(() => _imagePaths.clear()),
              child: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _addDropped(details.files.map((f) => f.path).toList());
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Layout Settings Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurfaceVariant,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                      ),
                    ),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<_ImagePagePreset>(
                        value: _preset,
                        underline: const SizedBox(),
                        items: _ImagePagePreset.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _preset = v);
                        },
                      ),
                      if (_preset != _ImagePagePreset.fitImage)
                        FilterChip(
                          label: Text(_landscape ? 'Landscape' : 'Portrait'),
                          avatar: Icon(
                            _landscape
                                ? Icons.crop_landscape_rounded
                                : Icons.crop_portrait_rounded,
                            size: 16,
                          ),
                          selected: _landscape,
                          onSelected: (v) => setState(() => _landscape = v),
                        ),
                      DropdownButton<double>(
                        value: _margin,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 0.0,
                            child: Text('No Margin'),
                          ),
                          DropdownMenuItem(
                            value: 12.0,
                            child: Text('Small Margin'),
                          ),
                          DropdownMenuItem(
                            value: 18.0,
                            child: Text('Standard Margin'),
                          ),
                          DropdownMenuItem(
                            value: 36.0,
                            child: Text('Wide Margin'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _margin = v);
                        },
                      ),
                    ],
                  ),
                ),

                // Image List
                Expanded(
                  child: _imagePaths.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.toolBlue.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 36,
                                    color: AppTheme.toolBlue,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Drop PNG/JPG images here or click Add Images',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Drag to reorder images and customize PDF page dimensions and margins.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _pickImages,
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('Select Images'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _imagePaths.length,
                          onReorder: (oldIdx, newIdx) {
                            setState(() {
                              if (newIdx > oldIdx) newIdx -= 1;
                              final item = _imagePaths.removeAt(oldIdx);
                              _imagePaths.insert(newIdx, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final path = _imagePaths[index];
                            return Card(
                              key: ValueKey('img_${index}_$path'),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(
                                        Icons.drag_indicator_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(path),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  p.basename(path),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('Page ${index + 1}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(
                                    () => _imagePaths.removeAt(index),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_imagePaths.length} image(s) queued',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: (_imagePaths.isNotEmpty && !_isBuilding)
                            ? _buildPdf
                            : null,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(_isBuilding ? 'Building...' : 'Build PDF'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: AppTheme.toolBlue.withValues(alpha: 0.85),
                  child: const Center(
                    child: Text(
                      'Drop Images to Add to PDF Builder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
