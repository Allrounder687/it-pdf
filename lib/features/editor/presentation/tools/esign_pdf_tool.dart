import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../signatures/presentation/signature_pad_dialog.dart';
import 'pdf_tool_model.dart';

class EsignPdfTool extends PdfTool {
  const EsignPdfTool();

  @override
  String get id => 'signatures';

  @override
  String get title => 'Handwritten eSign';

  @override
  String get description =>
      'Draw, save and manage custom vector signatures for rapid signing.';

  @override
  IconData get icon => Icons.draw_outlined;

  @override
  Color get color => AppTheme.toolAmber;

  @override
  ToolCategory get category => ToolCategory.security;

  @override
  String get badge => 'SIGN';

  @override
  List<String> get searchKeywords => const [
    'sign',
    'signature',
    'draw',
    'esign',
    'handwriting',
    'ink',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => const SignaturePadDialog(),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signature profile saved! Ready for 1-click signing.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
