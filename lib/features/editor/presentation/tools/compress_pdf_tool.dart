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

class CompressPdfTool extends PdfTool {
  const CompressPdfTool();

  @override
  String get id => 'compress';

  @override
  String get title => 'Compress PDF';

  @override
  String get description =>
      'Reduce PDF file size using stream compaction or smart DPI re-encoding.';

  @override
  IconData get icon => Icons.compress_rounded;

  @override
  Color get color => AppTheme.toolCoral;

  @override
  ToolCategory get category => ToolCategory.optimize;

  @override
  String get badge => 'POPULAR';

  @override
  List<String> get searchKeywords => const [
    'compress',
    'shrink',
    'reduce',
    'size',
    'optimize',
    'small',
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
          content: Text('Cannot compress an encrypted or unreadable PDF.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _CompressPdfStudioScreen(sourcePath: path, summary: summary),
      ),
    );
  }
}

class _CompressPdfStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final PdfFileSummary summary;

  const _CompressPdfStudioScreen({
    required this.sourcePath,
    required this.summary,
  });

  @override
  ConsumerState<_CompressPdfStudioScreen> createState() =>
      _CompressPdfStudioScreenState();
}

class _CompressPdfStudioScreenState
    extends ConsumerState<_CompressPdfStudioScreen> {
  PdfCompressionMode _mode = PdfCompressionMode.lossless;
  bool _isCompressing = false;
  int _done = 0;
  int _total = 0;
  PdfCompressionResult? _result;

  Future<void> _runCompression() async {
    final filePicker = ref.read(filePickerServiceProvider);
    final baseName = p.basenameWithoutExtension(widget.sourcePath);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '${baseName}_compressed.pdf',
      dialogTitle: 'Save Compressed PDF',
    );
    if (dest == null || !mounted) return;

    setState(() {
      _isCompressing = true;
      _done = 0;
      _total = widget.summary.pageCount;
      _result = null;
    });

    try {
      final res = await ref
          .read(syncfusionPdfServiceProvider)
          .compressPdf(
            sourcePath: widget.sourcePath,
            outputPath: dest,
            mode: _mode,
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
        await ref
            .read(libraryNotifierProvider.notifier)
            .importFileFromPath(dest);
        setState(() {
          _isCompressing = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.sourcePath);

    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF Studio')),
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
                      Icons.compress_rounded,
                      color: AppTheme.toolCoral,
                      size: 32,
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Original Size: ${formatFileSize(widget.summary.fileSizeBytes)} • ${widget.summary.pageCount} pages',
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Choose Compression Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),

                for (final mode in PdfCompressionMode.values)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _mode == mode
                            ? AppTheme.toolCoral
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isCompressing
                          ? null
                          : () => setState(() => _mode = mode),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              _mode == mode
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: _mode == mode
                                  ? AppTheme.toolCoral
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mode.subtitle,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_isCompressing) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _total > 0 ? (_done / _total) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mode == PdfCompressionMode.lossless
                        ? 'Optimizing PDF object streams...'
                        : 'Re-encoding page $_done of $_total...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],

                if (_result != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _result!.savedPercentage > 0
                                  ? 'Reduced by ${_result!.savedPercentage.toStringAsFixed(1)}%!'
                                  : 'Stream optimization complete!',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatFileSize(_result!.originalBytes)}  →  ${formatFileSize(_result!.compressedBytes)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved to: ${_result!.outputPath}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final doc = await ref
                                .read(libraryNotifierProvider.notifier)
                                .importFileFromPath(_result!.outputPath);
                            if (doc != null && context.mounted) {
                              ref
                                  .read(documentTabsNotifierProvider.notifier)
                                  .openTab(doc);
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open Compressed PDF'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _isCompressing ? null : _runCompression,
                  icon: const Icon(Icons.compress_rounded),
                  label: Text(
                    _isCompressing ? 'Compressing...' : 'Compress & Save PDF',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.toolCoral,
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
