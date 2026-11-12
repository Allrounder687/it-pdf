import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/providers.dart';
import '../../../ai_assistant/presentation/ai_assistant_sheet.dart';
import '../../../annotations/domain/annotation_notifier.dart';
import 'pdf_tool_model.dart';

class AiAssistantTool extends PdfTool {
  const AiAssistantTool();

  @override
  String get id => 'ai_assistant';

  @override
  String get title => 'AI Document Assistant';

  @override
  String get description =>
      'Grounded conversation, instant summaries, key dates and citations.';

  @override
  IconData get icon => Icons.auto_awesome_rounded;

  @override
  Color get color => AppTheme.toolViolet;

  @override
  ToolCategory get category => ToolCategory.ai;

  @override
  String get badge => 'SMART AI';

  @override
  List<String> get searchKeywords => const [
    'ai',
    'chat',
    'summarize',
    'summary',
    'ask',
    'assistant',
    'smart',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final pdfService = ref.read(syncfusionPdfServiceProvider);

    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyzing document text with grounded AI...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final texts = await pdfService.extractDocumentText(path);
      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AiAssistantSheet(
          pageTexts: texts,
          onJumpToPage: (_) => Navigator.of(ctx).pop(),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text for AI: $e')),
        );
      }
    }
  }
}
