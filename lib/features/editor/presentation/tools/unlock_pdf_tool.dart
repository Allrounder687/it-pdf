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

class UnlockPdfTool extends PdfTool {
  const UnlockPdfTool();

  @override
  String get id => 'unlock';

  @override
  String get title => 'Unlock / Decrypt PDF';

  @override
  String get description =>
      'Remove password protection & restrictions from authorized encrypted PDFs.';

  @override
  IconData get icon => Icons.lock_open_rounded;

  @override
  Color get color => AppTheme.toolAmber;

  @override
  ToolCategory get category => ToolCategory.security;

  @override
  String get badge => 'DECRYPT';

  @override
  List<String> get searchKeywords => const [
    'unlock',
    'decrypt',
    'remove password',
    'unprotect',
    'open',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final path = await filePicker.pickPdfFile();
    if (path == null || !context.mounted) return;

    final passController = TextEditingController();
    bool obscure = true;
    String? errorMsg;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: AppTheme.toolAmber),
              SizedBox(width: 8),
              Text('Unlock PDF'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: ${p.basename(path)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Current PDF Password',
                    errorText: errorMsg,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passController.text.isEmpty) {
                  setDialogState(() => errorMsg = 'Password is required.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Unlock & Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final baseName = p.basenameWithoutExtension(path);
    final dest = await filePicker.pickSaveFilePath(
      defaultFileName: '${baseName}_unlocked.pdf',
      dialogTitle: 'Save Unlocked PDF',
    );
    if (dest == null || !context.mounted) return;

    try {
      await ref
          .read(syncfusionPdfServiceProvider)
          .unlockPdf(
            sourcePath: path,
            currentPassword: passController.text,
            outputPath: dest,
          );
      final doc = await ref
          .read(libraryNotifierProvider.notifier)
          .importFileFromPath(dest);
      if (!context.mounted) return;
      if (doc != null) {
        ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unlocked PDF saved cleanly to ${p.basename(dest)}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlock failed (verify password): $e')),
        );
      }
    }
  }
}
