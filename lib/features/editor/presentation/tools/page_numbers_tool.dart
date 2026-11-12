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

class PageNumbersTool extends PdfTool {
  const PageNumbersTool();

  @override
  String get id => 'page_numbers';

  @override
  String get title => 'Page Numbers & Bates';

  @override
  String get description =>
      'Stamp dynamic page numbers or legal Bates prefixes across all pages.';

  @override
  IconData get icon => Icons.format_list_numbered_rounded;

  @override
  Color get color => AppTheme.toolTeal;

  @override
  ToolCategory get category => ToolCategory.optimize;

  @override
  String get badge => 'PRO';

  @override
  List<String> get searchKeywords => const [
    'page numbers',
    'bates',
    'footer',
    'header',
    'numbering',
    'pagination',
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
          content: Text('Cannot number an encrypted or unreadable PDF.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _PageNumbersStudioScreen(sourcePath: path, summary: summary),
      ),
    );
  }
}

class _PageNumbersStudioScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final PdfFileSummary summary;

  const _PageNumbersStudioScreen({
    required this.sourcePath,
    required this.summary,
  });

  @override
  ConsumerState<_PageNumbersStudioScreen> createState() =>
      _PageNumbersStudioScreenState();
}

class _PageNumbersStudioScreenState
    extends ConsumerState<_PageNumbersStudioScreen> {
  PageNumberPosition _position = PageNumberPosition.bottomCenter;
  final TextEditingController _formatController = TextEditingController(
    text: 'Page {n} of {total}',
  );
  int _startNumber = 1;
  bool _skipFirstPage = false;
  double _fontSize = 11;
  bool _isApplying = false;

  static const _formatPresets = [
    ('Page {n} of {total}', 'Standard'),
    ('{n} / {total}', 'Compact'),
    ('{n}', 'Number Only'),
    ('EX-{bates}', 'Bates Legal'),
  ];

  @override
  void dispose() {
    _formatController.dispose();
    super.dispose();
  }

  String _renderSampleLabel() {
    final total = _skipFirstPage
        ? (widget.summary.pageCount - 1).clamp(1, 9999)
        : widget.summary.pageCount;
    return _formatController.text
        .replaceAll('{n}', '$_startNumber')
        .replaceAll('{total}', '$total')
        .replaceAll('{bates}', _startNumber.toString().padLeft(4, '0'));
  }

  Future<void> _apply() async {
    final format = _formatController.text.trim();
    if (format.isEmpty) return;

    final filePicker = ref.read(filePickerServiceProvider);
    final baseName = p.basenameWithoutExtension(widget.sourcePath);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '${baseName}_numbered.pdf',
      dialogTitle: 'Save Numbered PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isApplying = true);
    try {
      await ref
          .read(syncfusionPdfServiceProvider)
          .addPageNumbers(
            sourcePath: widget.sourcePath,
            outputPath: dest,
            position: _position,
            format: format,
            startNumber: _startNumber,
            skipFirstPage: _skipFirstPage,
            fontSize: _fontSize,
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
          content: Text('Stamped page numbers onto ${p.basename(dest)}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Page numbering failed: $e')));
      }
    }
  }

  Widget _buildZoneCell(PageNumberPosition pos, String sample) {
    final isSelected = _position == pos;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _position = pos),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.toolTeal.withValues(alpha: 0.16)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.toolTeal : Colors.grey.shade400,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Text(
            isSelected ? sample : pos.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.toolTeal : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sample = _renderSampleLabel();

    return Scaffold(
      appBar: AppBar(title: const Text('Page Numbers & Bates Studio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Document: ${p.basename(widget.sourcePath)} (${widget.summary.pageCount} pages)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Stamp Placement',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),

                // 6-zone interactive page frame
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildZoneCell(PageNumberPosition.topLeft, sample),
                          const SizedBox(width: 8),
                          _buildZoneCell(PageNumberPosition.topCenter, sample),
                          const SizedBox(width: 8),
                          _buildZoneCell(PageNumberPosition.topRight, sample),
                        ],
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Page Body Content',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          _buildZoneCell(PageNumberPosition.bottomLeft, sample),
                          const SizedBox(width: 8),
                          _buildZoneCell(
                            PageNumberPosition.bottomCenter,
                            sample,
                          ),
                          const SizedBox(width: 8),
                          _buildZoneCell(
                            PageNumberPosition.bottomRight,
                            sample,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _formatController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Stamp Format ({n}, {total}, {bates})',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _formatPresets
                      .map(
                        (p) => ActionChip(
                          label: Text(
                            p.$2,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () => setState(() {
                            _formatController.text = p.$1;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Starting Number:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: _startNumber > 1
                          ? () => setState(() => _startNumber--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_startNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _startNumber++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Skip Cover Page (Page 1)'),
                  value: _skipFirstPage,
                  onChanged: (v) => setState(() => _skipFirstPage = v),
                ),

                Text('Font Size: ${_fontSize.round()} pt'),
                Slider(
                  value: _fontSize,
                  min: 8,
                  max: 20,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),

                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isApplying ? null : _apply,
                  icon: const Icon(Icons.format_list_numbered_rounded),
                  label: Text(
                    _isApplying ? 'Stamping...' : 'Apply Page Numbers & Save',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.toolTeal,
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
