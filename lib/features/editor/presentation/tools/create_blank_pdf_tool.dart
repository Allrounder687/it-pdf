import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/pdf_engine/advanced_pdf_operations.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import 'pdf_tool_model.dart';

class CreateBlankPdfTool extends PdfTool {
  const CreateBlankPdfTool();

  @override
  String get id => 'create_blank';

  @override
  String get title => 'Notebook & Template Studio';

  @override
  String get description =>
      'Generate custom multi-page Blank, Ruled, Engineering Grid, or Bullet Journal PDFs.';

  @override
  IconData get icon => Icons.note_add_outlined;

  @override
  Color get color => AppTheme.toolCoral;

  @override
  ToolCategory get category => ToolCategory.convert;

  @override
  String get badge => 'TEMPLATES';

  @override
  List<String> get searchKeywords => const [
    'blank',
    'new',
    'create',
    'notebook',
    'lined',
    'grid',
    'dotted',
    'template',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _CreateBlankPdfStudioScreen(),
      ),
    );
  }
}

enum _PaperSizeOption {
  a4('A4', sf.PdfPageSize.a4),
  letter('US Letter', sf.PdfPageSize.letter),
  legal('US Legal', sf.PdfPageSize.legal);

  final String label;
  final Size size;
  const _PaperSizeOption(this.label, this.size);
}

class _CreateBlankPdfStudioScreen extends ConsumerStatefulWidget {
  const _CreateBlankPdfStudioScreen();

  @override
  ConsumerState<_CreateBlankPdfStudioScreen> createState() =>
      _CreateBlankPdfStudioScreenState();
}

class _CreateBlankPdfStudioScreenState
    extends ConsumerState<_CreateBlankPdfStudioScreen> {
  final _titleController = TextEditingController(text: 'New Notebook');
  BlankPaperTemplate _template = BlankPaperTemplate.lined;
  _PaperSizeOption _paperSize = _PaperSizeOption.a4;
  int _pageCount = 10;
  Color _paperColor = const Color(0xFFFFFFFF);
  bool _isCreating = false;

  static const _paperTints = [
    (label: 'Crisp White', color: Color(0xFFFFFFFF)),
    (label: 'Warm Cream', color: Color(0xFFFEFCE8)),
    (label: 'Soft Slate', color: Color(0xFFF1F5F9)),
    (label: 'Blueprint', color: Color(0xFF1E3A8A)),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final title = _titleController.text.trim().isEmpty
        ? 'New Document'
        : _titleController.text.trim();
    final filePicker = ref.read(filePickerServiceProvider);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '$title.pdf',
      dialogTitle: 'Save Generated Notebook PDF',
    );
    if (dest == null || !mounted) return;

    setState(() => _isCreating = true);
    try {
      await ref
          .read(syncfusionPdfServiceProvider)
          .createTemplatedDocument(
            title: title,
            outputPath: dest,
            template: _template,
            pageSize: _paperSize.size,
            pageCount: _pageCount,
            backgroundColor: _paperColor,
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
          content: Text('Generated $_pageCount-page ${_template.label} PDF!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template generation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notebook & Template Studio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Paper Pattern Template',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: BlankPaperTemplate.values
                      .map(
                        (t) => ChoiceChip(
                          label: Text(t.label),
                          selected: _template == t,
                          onSelected: (_) => setState(() => _template = t),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Page Dimensions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_PaperSizeOption>(
                  segments: _PaperSizeOption.values
                      .map((o) => ButtonSegment(value: o, label: Text(o.label)))
                      .toList(),
                  selected: {_paperSize},
                  onSelectionChanged: (s) =>
                      setState(() => _paperSize = s.first),
                ),
                const SizedBox(height: 18),

                Text(
                  'Page Count: $_pageCount pages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _pageCount.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '$_pageCount',
                  onChanged: (v) => setState(() => _pageCount = v.round()),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Paper Tint',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _paperTints
                      .map(
                        (tint) => ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: tint.color,
                            radius: 8,
                          ),
                          label: Text(tint.label),
                          selected: _paperColor == tint.color,
                          onSelected: (_) =>
                              setState(() => _paperColor = tint.color),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _generate,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(
                    _isCreating
                        ? 'Generating PDF...'
                        : 'Generate $_pageCount-Page PDF',
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
