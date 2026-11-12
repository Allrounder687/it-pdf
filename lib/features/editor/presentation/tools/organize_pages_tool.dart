import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/providers.dart';
import '../../../library/domain/library_notifier.dart';
import '../../../page_organizer/domain/page_organizer_notifier.dart';
import '../../../page_organizer/presentation/page_organizer_screen.dart';
import 'pdf_tool_model.dart';

class OrganizePagesTool extends PdfTool {
  const OrganizePagesTool();

  @override
  String get id => 'organize';

  @override
  String get title => 'Organize & Rotate Pages';

  @override
  String get description =>
      'Visually drag-and-drop reorder, rotate 90°, duplicate or delete pages.';

  @override
  IconData get icon => Icons.dashboard_customize_outlined;

  @override
  Color get color => AppTheme.toolIndigo;

  @override
  ToolCategory get category => ToolCategory.organize;

  @override
  String get badge => 'VISUAL';

  @override
  List<String> get searchKeywords => const [
    'organize',
    'rotate',
    'reorder',
    'delete',
    'duplicate',
    'sort',
  ];

  @override
  Future<void> execute(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(filePickerServiceProvider);
    final libraryNotifier = ref.read(libraryNotifierProvider.notifier);

    final path = await filePicker.pickPdfFile();
    if (path == null) return;

    final doc = await libraryNotifier.importFileFromPath(path);
    if (doc == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageOrganizerScreen(
          params: PageOrganizerParams(
            path: doc.path,
            id: doc.id,
            name: doc.name,
            pageCount: doc.totalPages,
          ),
        ),
      ),
    );
  }
}
