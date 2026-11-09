import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/providers.dart';
import '../domain/page_item.dart';
import '../domain/page_organizer_notifier.dart';

/// Workspace screen for page reordering, rotation, deletion and page extraction.
class PageOrganizerScreen extends ConsumerWidget {
  final PageOrganizerParams params;

  const PageOrganizerScreen({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pageOrganizerNotifierProvider(params));
    final notifier = ref.read(pageOrganizerNotifierProvider(params).notifier);
    final filePicker = ref.watch(filePickerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Page Organizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${state.pages.length} Pages • ${params.name}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (state.selectedPages.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.deselect),
              label: const Text('Deselect'),
              onPressed: () => notifier.clearSelection(),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.select_all),
              label: const Text('Select All'),
              onPressed: () => notifier.selectAll(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(state.statusMessage ?? 'Processing...'),
                ],
              ),
            )
          : state.pages.isEmpty
              ? const Center(child: Text('No pages in document'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.pages.length,
                    itemBuilder: (context, index) {
                      final item = state.pages[index];
                      return _PageCard(
                        item: item,
                        index: index,
                        onToggleSelect: () => notifier.toggleSelect(index),
                        onRotate: () => notifier.rotatePage(index, 90),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: state.selectedPages.isEmpty
          ? null
          : _OrganizerBottomBar(
              selectedCount: state.selectedPages.length,
              onRotateSelected: () => notifier.rotateSelected(90),
              onDeleteSelected: () => _confirmDelete(context, notifier),
              onExtractSelected: () => _handleExtract(context, notifier, filePicker),
            ),
    );
  }

  void _confirmDelete(BuildContext context, PageOrganizerNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pages?'),
        content: const Text(
          'Are you sure you want to remove the selected pages from this document workspace?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.deleteSelected();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExtract(
    BuildContext context,
    PageOrganizerNotifier notifier,
    FilePickerService filePicker,
  ) async {
    final destination = await filePicker.getSaveDestinationPath(
      defaultFileName: 'extracted_pages.pdf',
    );

    if (destination != null) {
      final success = await notifier.exportSelected(outputPath: destination);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully extracted pages to $destination'
                  : 'Failed to extract pages.',
            ),
          ),
        );
      }
    }
  }
}

class _PageCard extends StatelessWidget {
  final PageItem item;
  final int index;
  final VoidCallback onToggleSelect;
  final VoidCallback onRotate;

  const _PageCard({
    required this.item,
    required this.index,
    required this.onToggleSelect,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: item.isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: item.isSelected ? Colors.blueAccent : (isDark ? Colors.white12 : Colors.black12),
          width: item.isSelected ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onToggleSelect,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF131B2A) : Colors.grey.shade100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: (item.rotationDegrees / 90).round(),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 40,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Page ${item.originalPageNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Checkbox(
                        value: item.isSelected,
                        onChanged: (_) => onToggleSelect(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.rotate_right, size: 20),
                        tooltip: 'Rotate 90°',
                        onPressed: onRotate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (item.rotationDegrees > 0)
                    Text(
                      '${item.rotationDegrees}°',
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizerBottomBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onRotateSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onExtractSelected;

  const _OrganizerBottomBar({
    required this.selectedCount,
    required this.onRotateSelected,
    required this.onDeleteSelected,
    required this.onExtractSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$selectedCount selected',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Rotate Selected',
              onPressed: onRotateSelected,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Extract to New PDF',
              onPressed: onExtractSelected,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Selected',
              onPressed: onDeleteSelected,
            ),
          ],
        ),
      ),
    );
  }
}
