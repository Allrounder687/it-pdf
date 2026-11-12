import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../ai_assistant/domain/ai_document_service.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import 'pdf_tool_model.dart';

/// 1-Click Grounded Document Insights — instant offline summary, key dates, and action items.
/// Zero API keys, zero confusing configurations.
class AiAssistantTool extends PdfTool {
  const AiAssistantTool();

  @override
  String get id => 'ai_assistant';

  @override
  String get title => 'Document Insights & Summary';

  @override
  String get description =>
      'Instant 1-click grounded insights — executive summaries, key dates, and action items with zero setup.';

  @override
  IconData get icon => Icons.insights_rounded;

  @override
  Color get color => const Color(0xFF8B5CF6);

  @override
  ToolCategory get category => ToolCategory.ai;

  @override
  String get badge => '1-CLICK';

  @override
  List<String> get searchKeywords => const [
    'summary',
    'insights',
    'dates',
    'action items',
    'extract',
    'analyze',
    'overview',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final pdfService = ref.read(syncfusionPdfServiceProvider);

    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    if (!context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(width: 16),
                  Text('Extracting grounded insights...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final texts = await pdfService.extractDocumentText(path);
      final aiService = AiDocumentService();
      final summary = aiService.generateSummary(texts);
      final dates = aiService.extractKeyDates(texts);
      final actions = aiService.extractActionItems(texts);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      await showDialog<void>(
        context: context,
        builder: (ctx) => _DocumentInsightsDialog(
          summary: summary,
          dates: dates,
          actions: actions,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to extract document insights: $e')),
      );
    }
  }
}

class _DocumentInsightsDialog extends StatefulWidget {
  final String summary;
  final String dates;
  final String actions;

  const _DocumentInsightsDialog({
    required this.summary,
    required this.dates,
    required this.actions,
  });

  @override
  State<_DocumentInsightsDialog> createState() =>
      _DocumentInsightsDialogState();
}

class _DocumentInsightsDialogState extends State<_DocumentInsightsDialog> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeText = _tab == 0
        ? widget.summary
        : (_tab == 1 ? widget.dates : widget.actions);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Colors.blueAccent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '1-Click Document Insights',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Copy to Clipboard',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: activeText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied insights to clipboard!')),
              );
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 480,
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Summary'),
                  icon: Icon(Icons.summarize_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Key Dates'),
                  icon: Icon(Icons.calendar_today_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Action Items'),
                  icon: Icon(Icons.task_alt, size: 16),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (set) => setState(() => _tab = set.first),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    activeText,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
