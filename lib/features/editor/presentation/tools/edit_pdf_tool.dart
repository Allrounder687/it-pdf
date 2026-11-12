import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../reader/domain/document_tabs_notifier.dart';
import '../../../reader/domain/reader_notifier.dart';
import '../../../reader/presentation/reader_screen.dart';
import '../../domain/editor_notifier.dart';
import '../../domain/editor_state.dart';
import 'pdf_tool_model.dart';

/// Premier dedicated PDF Editing tool for visual object manipulation.
class EditPdfTool extends PdfTool {
  const EditPdfTool();

  @override
  String get id => 'edit_pdf';

  @override
  String get title => 'Edit PDF & Visual Objects';

  @override
  String get description =>
      'Full visual editing — add/edit live text, insert signatures, draw vector shapes, and modify page content.';

  @override
  IconData get icon => Icons.edit_note_rounded;

  @override
  Color get color => const Color(0xFF3B82F6);

  @override
  ToolCategory get category => ToolCategory.edit;

  @override
  String get badge => 'STUDIO';

  @override
  List<String> get searchKeywords => const [
    'edit',
    'editor',
    'modify',
    'text',
    'draw',
    'signature',
    'shape',
    'canvas',
    'object',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final filePicker = ref.read(filePickerServiceProvider);
    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    final doc = await ref
        .read(libraryNotifierProvider.notifier)
        .importFileFromPath(path);
    if (doc == null || !context.mounted) return;

    if (isDesktop) {
      ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
      // Auto-activate Edit mode
      final params = EditorNotifierParams(
        documentId: doc.id,
        documentPath: doc.path,
      );
      ref
          .read(editorNotifierProvider(params).notifier)
          .setWorkspaceMode(WorkspaceMode.edit);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            params: ReaderNotifierParams(
              id: doc.id,
              name: doc.name,
              path: doc.path,
              initialPage: doc.lastPageRead,
              initialPageCount: doc.totalPages,
            ),
          ),
        ),
      );
    }
  }
}
