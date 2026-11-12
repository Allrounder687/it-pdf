import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/providers.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import 'pdf_tool_model.dart';

class ExtractTextTool extends PdfTool {
  const ExtractTextTool();

  @override
  String get id => 'extract_text';

  @override
  String get title => 'Text Extraction Workbench';

  @override
  String get description =>
      'Inspect word/char telemetry, search across pages, copy text, or export .txt files.';

  @override
  IconData get icon => Icons.text_snippet_outlined;

  @override
  Color get color => AppTheme.toolBlue;

  @override
  ToolCategory get category => ToolCategory.convert;

  @override
  String get badge => 'TXT EXPORT';

  @override
  List<String> get searchKeywords => const [
    'extract',
    'text',
    'copy',
    'txt',
    'word count',
    'search',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final pdfService = ref.read(syncfusionPdfServiceProvider);

    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    try {
      final texts = await pdfService.extractDocumentText(path);
      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              _ExtractTextWorkbenchScreen(sourcePath: path, pageTexts: texts),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Text extraction failed: $e')));
      }
    }
  }
}

class _ExtractTextWorkbenchScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final Map<int, String> pageTexts;

  const _ExtractTextWorkbenchScreen({
    required this.sourcePath,
    required this.pageTexts,
  });

  @override
  ConsumerState<_ExtractTextWorkbenchScreen> createState() =>
      _ExtractTextWorkbenchScreenState();
}

class _ExtractTextWorkbenchScreenState
    extends ConsumerState<_ExtractTextWorkbenchScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String _compiledFullText(Iterable<MapEntry<int, String>> entries) {
    return entries.map((e) => '=== Page ${e.key} ===\n${e.value}').join('\n\n');
  }

  int _totalWords() {
    int count = 0;
    for (final text in widget.pageTexts.values) {
      final cleaned = text.trim();
      if (cleaned.isEmpty) continue;
      count += cleaned.split(RegExp(r'\s+')).length;
    }
    return count;
  }

  int _totalChars() {
    int count = 0;
    for (final text in widget.pageTexts.values) {
      count += text.length;
    }
    return count;
  }

  Future<void> _exportTxt(String fullText) async {
    final baseName = p.basenameWithoutExtension(widget.sourcePath);
    final bytes = Uint8List.fromList(utf8.encode(fullText));
    final dest = await ref
        .read(filePickerServiceProvider)
        .pickSaveFilePath(
          defaultFileName: '${baseName}_extracted.txt',
          initialBytes: bytes,
          dialogTitle: 'Export Extracted Text (.txt)',
        );
    if (dest == null || !mounted) return;
    await File(dest).writeAsBytes(bytes, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported text to ${p.basename(dest)}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = widget.pageTexts.entries.where((e) {
      if (_query.isEmpty) return true;
      return e.value.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final fullText = _compiledFullText(widget.pageTexts.entries);

    return Scaffold(
      appBar: AppBar(
        title: Text('Text Workbench — ${p.basename(widget.sourcePath)}'),
        actions: [
          IconButton(
            tooltip: 'Copy All Text',
            icon: const Icon(Icons.copy_rounded),
            onPressed: fullText.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: fullText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied all document text.'),
                        ),
                      );
                    }
                  },
          ),
          TextButton.icon(
            onPressed: fullText.isEmpty ? null : () => _exportTxt(fullText),
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: const Text('Export .TXT'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Telemetry & Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.description_outlined, size: 16),
                      label: Text('${widget.pageTexts.length} Pages'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.notes_rounded, size: 16),
                      label: Text('${_totalWords()} Words'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.text_fields_rounded, size: 16),
                      label: Text('${_totalChars()} Characters'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _filterController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Filter pages containing text...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(child: Text('No matching pages found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page ${entry.key}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.toolBlue,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 16,
                                    ),
                                    tooltip: 'Copy page text',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: entry.value),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Copied Page ${entry.key} text.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),
                              SelectableText(
                                entry.value.isEmpty
                                    ? '(No embedded text on this page)'
                                    : entry.value,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
