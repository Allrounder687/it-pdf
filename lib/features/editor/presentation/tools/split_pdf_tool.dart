import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../page_organizer/domain/page_organizer_notifier.dart';
import '../../../page_organizer/presentation/page_organizer_screen.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import 'pdf_tool_model.dart';

class SplitPdfTool extends PdfTool {
  const SplitPdfTool();

  @override
  String get id => 'split';

  @override
  String get title => 'Split & Burst Studio';

  @override
  String get description =>
      'Extract custom ranges, split cleanly every N pages, or burst into single-page PDFs.';

  @override
  IconData get icon => Icons.call_split_rounded;

  @override
  Color get color => AppTheme.toolTeal;

  @override
  ToolCategory get category => ToolCategory.organize;

  @override
  String get badge => 'STUDIO';

  @override
  List<String> get searchKeywords => const [
    'split',
    'extract',
    'burst',
    'range',
    'chunk',
    'separate',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final libraryNotifier = ref.read(libraryNotifierProvider.notifier);

    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    final summary = await ref
        .read(syncfusionPdfServiceProvider)
        .inspectPdf(path);
    if (!context.mounted) return;
    if (summary.isEncrypted || summary.pageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unlock or select a valid readable PDF first.'),
        ),
      );
      return;
    }

    final doc = await libraryNotifier.importFileFromPath(path);
    if (doc == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SplitPdfStudioScreen(
          sourcePath: doc.path,
          docId: doc.id,
          docName: doc.name,
          pageCount: summary.pageCount,
          fileSizeBytes: summary.fileSizeBytes,
        ),
      ),
    );
  }
}

enum _SplitMode { customRange, everyNPages, burstAll }

class _SplitPdfStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final String docId;
  final String docName;
  final int pageCount;
  final int fileSizeBytes;

  const _SplitPdfStudioScreen({
    required this.sourcePath,
    required this.docId,
    required this.docName,
    required this.pageCount,
    required this.fileSizeBytes,
  });

  @override
  ConsumerState<_SplitPdfStudioScreen> createState() =>
      _SplitPdfStudioScreenState();
}

class _SplitPdfStudioScreenState extends ConsumerState<_SplitPdfStudioScreen> {
  _SplitMode _mode = _SplitMode.customRange;
  late final TextEditingController _rangeController;
  int _pagesPerChunk = 2;
  bool _isProcessing = false;
  int _progressDone = 0;
  int _progressTotal = 0;

  @override
  void initState() {
    super.initState();
    _rangeController = TextEditingController(
      text: widget.pageCount > 1 ? '1-${(widget.pageCount / 2).ceil()}' : '1',
    );
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  String _previewSummary() {
    switch (_mode) {
      case _SplitMode.customRange:
        final pages = parsePageRanges(_rangeController.text, widget.pageCount);
        return pages.isEmpty
            ? 'Enter valid pages between 1 and ${widget.pageCount}'
            : 'Outputs 1 PDF containing ${pages.length} selected page(s).';
      case _SplitMode.everyNPages:
        final chunks = (widget.pageCount / _pagesPerChunk).ceil();
        return 'Outputs $chunks PDF files inside your chosen folder.';
      case _SplitMode.burstAll:
        return 'Burst creates ${widget.pageCount} standalone 1-page PDF files.';
    }
  }

  Future<void> _executeSplit() async {
    final filePicker = ref.read(filePickerServiceProvider);
    final pdfService = ref.read(syncfusionPdfServiceProvider);

    if (_mode == _SplitMode.customRange) {
      final pages = parsePageRanges(_rangeController.text, widget.pageCount);
      if (pages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid page numbers.')),
        );
        return;
      }

      final dest = await filePicker.pickSaveFilePath(
        defaultFileName: 'extracted_${widget.docName}',
        dialogTitle: 'Save Extracted PDF',
      );
      if (dest == null || !mounted) return;

      setState(() => _isProcessing = true);
      try {
        await ref
            .read(pageOrganizerServiceProvider)
            .exportSelectedPages(
              sourcePath: widget.sourcePath,
              pageNumbers: pages,
              outputPath: dest,
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
              'Extracted ${pages.length} pages to ${p.basename(dest)}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
        }
      }
      return;
    }

    // Multi-file chunk / burst export
    final outDir = await filePicker.pickDirectoryPath(
      dialogTitle: 'Choose Output Folder for Split PDFs',
    );
    if (outDir == null || !mounted) return;

    final chunk = _mode == _SplitMode.burstAll ? 1 : _pagesPerChunk;
    setState(() {
      _isProcessing = true;
      _progressDone = 0;
      _progressTotal = (widget.pageCount / chunk).ceil();
    });

    try {
      final created = await pdfService.splitPdfIntoChunks(
        sourcePath: widget.sourcePath,
        outputDirectory: outDir,
        pagesPerChunk: chunk,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _progressDone = done;
              _progressTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${created.length} PDF files in $outDir'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Split failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split & Burst Studio'),
        actions: [
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PageOrganizerScreen(
                          params: PageOrganizerParams(
                            path: widget.sourcePath,
                            id: widget.docId,
                            name: widget.docName,
                            pageCount: widget.pageCount,
                          ),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: const Text('Visual Organizer'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File Header Card
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppTheme.toolTeal,
                      size: 32,
                    ),
                    title: Text(
                      widget.docName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${widget.pageCount} pages • ${formatFileSize(widget.fileSizeBytes)}',
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Split Strategy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),

                SegmentedButton<_SplitMode>(
                  segments: const [
                    ButtonSegment(
                      value: _SplitMode.customRange,
                      icon: Icon(Icons.filter_list_rounded),
                      label: Text('Custom Range'),
                    ),
                    ButtonSegment(
                      value: _SplitMode.everyNPages,
                      icon: Icon(Icons.view_agenda_outlined),
                      label: Text('Every N Pages'),
                    ),
                    ButtonSegment(
                      value: _SplitMode.burstAll,
                      icon: Icon(Icons.burst_mode_outlined),
                      label: Text('Burst All'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 20),

                if (_mode == _SplitMode.customRange) ...[
                  TextField(
                    controller: _rangeController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Page Ranges to Extract',
                      hintText: 'e.g. 1-3, 5, 8-12',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else if (_mode == _SplitMode.everyNPages) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pages per split output file:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _pagesPerChunk.clamp(1, widget.pageCount),
                        items: [
                          for (final n in [1, 2, 3, 5, 10, 20])
                            if (n <= widget.pageCount)
                              DropdownMenuItem(
                                value: n,
                                child: Text('$n pages'),
                              ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _pagesPerChunk = v);
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.toolTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.toolTeal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.toolTeal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _previewSummary(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isProcessing && _progressTotal > 0) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _progressDone / _progressTotal,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Generating chunk $_progressDone of $_progressTotal...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isProcessing ? null : _executeSplit,
                  icon: const Icon(Icons.call_split_rounded),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Execute Split',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
