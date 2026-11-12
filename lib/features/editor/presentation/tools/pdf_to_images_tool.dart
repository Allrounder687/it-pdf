import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import 'pdf_tool_model.dart';

class PdfToImagesTool extends PdfTool {
  const PdfToImagesTool();

  @override
  String get id => 'pdf_to_images';

  @override
  String get title => 'PDF to Images (PNG)';

  @override
  String get description =>
      'Render PDF pages into crisp 72–300 DPI PNG images via native PDFium.';

  @override
  IconData get icon => Icons.image_outlined;

  @override
  Color get color => AppTheme.toolBlue;

  @override
  ToolCategory get category => ToolCategory.convert;

  @override
  String get badge => 'HD EXPORT';

  @override
  List<String> get searchKeywords => const [
    'pdf to image',
    'png',
    'render',
    'export',
    'dpi',
    'convert',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    final summary = await ref
        .read(syncfusionPdfServiceProvider)
        .inspectPdf(path);
    if (!context.mounted) return;
    if (summary.isEncrypted || summary.pageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot render an encrypted or unreadable PDF.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _PdfToImagesStudioScreen(sourcePath: path, summary: summary),
      ),
    );
  }
}

class _PdfToImagesStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final PdfFileSummary summary;

  const _PdfToImagesStudioScreen({
    required this.sourcePath,
    required this.summary,
  });

  @override
  ConsumerState<_PdfToImagesStudioScreen> createState() =>
      _PdfToImagesStudioScreenState();
}

class _PdfToImagesStudioScreenState
    extends ConsumerState<_PdfToImagesStudioScreen> {
  int _dpi = 150;
  bool _allPages = true;
  late final TextEditingController _rangeController;
  bool _isExporting = false;
  int _done = 0;
  int _total = 0;
  List<String> _exportedFiles = [];

  @override
  void initState() {
    super.initState();
    _rangeController = TextEditingController(
      text: widget.summary.pageCount > 1
          ? '1-${widget.summary.pageCount}'
          : '1',
    );
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final pages = _allPages
        ? List<int>.generate(widget.summary.pageCount, (i) => i + 1)
        : parsePageRanges(_rangeController.text, widget.summary.pageCount);

    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid page numbers.')),
      );
      return;
    }

    final outDir = await ref
        .read(filePickerServiceProvider)
        .pickDirectoryPath(dialogTitle: 'Choose Folder for Exported PNGs');
    if (outDir == null || !mounted) return;

    setState(() {
      _isExporting = true;
      _done = 0;
      _total = pages.length;
      _exportedFiles = [];
    });

    try {
      final created = await ref
          .read(syncfusionPdfServiceProvider)
          .exportPagesToPngs(
            sourcePath: widget.sourcePath,
            outputDirectory: outDir,
            pageNumbers: pages,
            dpi: _dpi,
            onProgress: (d, t) {
              if (mounted) {
                setState(() {
                  _done = d;
                  _total = t;
                });
              }
            },
          );
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportedFiles = created;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PNG export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Images Studio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.image_outlined,
                      color: AppTheme.toolBlue,
                      size: 32,
                    ),
                    title: Text(
                      p.basename(widget.sourcePath),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${widget.summary.pageCount} pages • ${formatFileSize(widget.summary.fileSizeBytes)}',
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Render Resolution (DPI)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 72, label: Text('72 DPI (Web)')),
                    ButtonSegment(
                      value: 150,
                      label: Text('150 DPI (Standard)'),
                    ),
                    ButtonSegment(value: 300, label: Text('300 DPI (Print)')),
                  ],
                  selected: {_dpi},
                  onSelectionChanged: _isExporting
                      ? null
                      : (s) => setState(() => _dpi = s.first),
                ),
                const SizedBox(height: 20),

                SwitchListTile(
                  title: const Text('Export All Pages'),
                  subtitle: Text('${widget.summary.pageCount} total pages'),
                  value: _allPages,
                  onChanged: _isExporting
                      ? null
                      : (v) => setState(() => _allPages = v),
                ),

                if (!_allPages) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rangeController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Page Range',
                      hintText: 'e.g. 1-4, 7',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                if (_isExporting) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: _total > 0 ? _done / _total : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rendering page $_done of $_total at $_dpi DPI...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],

                if (_exportedFiles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exported ${_exportedFiles.length} PNG image(s)!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Folder: ${p.dirname(_exportedFiles.first)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _export,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    _isExporting ? 'Exporting PNGs...' : 'Export Pages as PNG',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.toolBlue,
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
