import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import 'pdf_tool_model.dart';

class MergePdfTool extends PdfTool {
  const MergePdfTool();

  @override
  String get id => 'merge';

  @override
  String get title => 'Merge PDF Studio';

  @override
  String get description =>
      'Reorder PDFs, pick custom page subsets per file, and auto-generate TOC bookmarks.';

  @override
  IconData get icon => Icons.call_merge_rounded;

  @override
  Color get color => AppTheme.toolTeal;

  @override
  ToolCategory get category => ToolCategory.organize;

  @override
  String get badge => 'STUDIO';

  @override
  List<String> get searchKeywords => const [
    'merge',
    'combine',
    'join',
    'concat',
    'bookmarks',
    'reorder',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _MergePdfStudioScreen()),
    );
  }
}

class _QueuedPdfItem {
  final String id;
  final String path;
  final String name;
  final int pageCount;
  final int sizeBytes;
  final TextEditingController rangeController;

  _QueuedPdfItem({
    required this.id,
    required this.path,
    required this.name,
    required this.pageCount,
    required this.sizeBytes,
  }) : rangeController = TextEditingController();

  void dispose() => rangeController.dispose();
}

class _MergePdfStudioScreen extends ConsumerStatefulWidget {
  const _MergePdfStudioScreen();

  @override
  ConsumerState<_MergePdfStudioScreen> createState() =>
      _MergePdfStudioScreenState();
}

class _MergePdfStudioScreenState extends ConsumerState<_MergePdfStudioScreen> {
  final List<_QueuedPdfItem> _queue = [];
  bool _addBookmarks = true;
  bool _isDragging = false;
  bool _isMerging = false;
  int _nextId = 1;

  @override
  void dispose() {
    for (final item in _queue) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _addFiles(List<String> paths) async {
    final pdfService = ref.read(syncfusionPdfServiceProvider);
    for (final path in paths) {
      if (!path.toLowerCase().endsWith('.pdf')) continue;
      final summary = await pdfService.inspectPdf(path);
      if (!mounted) return;
      if (summary.isEncrypted || summary.pageCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped ${p.basename(path)}: encrypted or unreadable PDF.',
            ),
          ),
        );
        continue;
      }
      setState(() {
        _queue.add(
          _QueuedPdfItem(
            id: 'q_${_nextId++}',
            path: path,
            name: p.basename(path),
            pageCount: summary.pageCount,
            sizeBytes: summary.fileSizeBytes,
          ),
        );
      });
    }
  }

  Future<void> _pickAndAddFiles() async {
    final files = await ref
        .read(filePickerServiceProvider)
        .pickMultiplePdfFiles();
    if (files.isNotEmpty) {
      await _addFiles(files);
    }
  }

  int _computedTotalPages() {
    int total = 0;
    for (final item in _queue) {
      final raw = item.rangeController.text.trim();
      if (raw.isEmpty) {
        total += item.pageCount;
      } else {
        total += parsePageRanges(raw, item.pageCount).length;
      }
    }
    return total;
  }

  Future<void> _runMerge() async {
    if (_queue.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 PDF files to merge.')),
      );
      return;
    }

    final filePicker = ref.read(filePickerServiceProvider);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: 'merged_document.pdf',
      dialogTitle: 'Save Merged PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isMerging = true);
    try {
      final sources = _queue.map((item) {
        final raw = item.rangeController.text.trim();
        final pages = raw.isEmpty ? null : parsePageRanges(raw, item.pageCount);
        return PdfMergeSource(
          path: item.path,
          pageNumbers: pages,
          bookmarkTitle: p.basenameWithoutExtension(item.name),
        );
      }).toList();

      await ref
          .read(syncfusionPdfServiceProvider)
          .mergePdfsAdvanced(
            sources: sources,
            outputPath: dest,
            addBookmarks: _addBookmarks,
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
          content: Text('Merged ${_queue.length} PDFs successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = _computedTotalPages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDF Studio'),
        actions: [
          TextButton.icon(
            onPressed: _isMerging ? null : _pickAndAddFiles,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add PDFs'),
          ),
          if (_queue.isNotEmpty)
            TextButton(
              onPressed: _isMerging
                  ? null
                  : () {
                      for (final q in _queue) {
                        q.dispose();
                      }
                      setState(() => _queue.clear());
                    },
              child: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          await _addFiles(details.files.map((f) => f.path).toList());
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Top Options Banner
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
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bookmarks_outlined,
                        size: 18,
                        color: AppTheme.toolTeal,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Auto-generate clickable TOC bookmark per document',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: _addBookmarks,
                        onChanged: (v) => setState(() => _addBookmarks = v),
                      ),
                    ],
                  ),
                ),

                // Main Queue
                Expanded(
                  child: _queue.isEmpty
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
                                    color: AppTheme.toolTeal.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.call_merge_rounded,
                                    size: 36,
                                    color: AppTheme.toolTeal,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Drop PDF files here or click Add PDFs',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Reorder documents by dragging, choose custom page ranges per file, and compile into a bookmarked PDF.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _pickAndAddFiles,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('Select PDF Files'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _queue.length,
                          onReorder: (oldIdx, newIdx) {
                            setState(() {
                              if (newIdx > oldIdx) newIdx -= 1;
                              final item = _queue.removeAt(oldIdx);
                              _queue.insert(newIdx, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = _queue[index];
                            return Card(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(
                                        Icons.drag_indicator_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.toolTeal
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.toolTeal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.pageCount} pages • ${formatFileSize(item.sizeBytes)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: item.rangeController,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Pages (opt.)',
                                          hintText: 'All',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                      tooltip: 'Remove from queue',
                                      onPressed: () {
                                        setState(() {
                                          final removed = _queue.removeAt(
                                            index,
                                          );
                                          removed.dispose();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Compile Bar
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
                          '${_queue.length} file(s) queued • $totalPages output pages',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: (_queue.length >= 2 && !_isMerging)
                            ? _runMerge
                            : null,
                        icon: _isMerging
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.call_merge_rounded, size: 18),
                        label: Text(
                          _isMerging ? 'Merging...' : 'Compile Merged PDF',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: AppTheme.toolTeal.withValues(alpha: 0.85),
                  child: const Center(
                    child: Text(
                      'Drop PDFs to Append to Merge Queue',
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
