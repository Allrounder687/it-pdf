import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/providers.dart';
import '../domain/page_item.dart';
import '../domain/page_organizer_notifier.dart';

/// Workspace screen for visual page reordering, rotation, deletion, duplication and extraction.
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

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmDiscard(context, notifier);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Page Organizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${state.pages.length} Pages${state.isDirty ? " (Unsaved Edits)" : ""} • ${params.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: state.isDirty ? Colors.amber : Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            // Undo
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: state.canUndo ? () => notifier.undo() : null,
            ),
            // Redo
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: state.canRedo ? () => notifier.redo() : null,
            ),
            const VerticalDivider(width: 12, indent: 14, endIndent: 14),

            // Select all / Deselect
            if (state.selectedPages.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.deselect, size: 18),
                label: const Text('Deselect'),
                onPressed: () => notifier.clearSelection(),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('Select All'),
                onPressed: () => notifier.selectAll(),
              ),

            // Apply Changes Button
            if (state.isDirty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Apply Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _handleApplyChanges(context, notifier),
                ),
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
                ? const Center(child: Text('No pages in document workspace.'))
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: _OrganizerGrid(
                      documentPath: params.path,
                      pages: state.pages,
                      onReorder: (oldIdx, newIdx) => notifier.reorderPage(oldIdx, newIdx),
                      onToggleSelect: (idx) => notifier.toggleSelect(idx),
                      onRotate: (idx) => notifier.rotatePage(idx, 90),
                    ),
                  ),
        bottomNavigationBar: state.selectedPages.isEmpty
            ? null
            : _OrganizerBottomBar(
                selectedCount: state.selectedPages.length,
                onRotateSelected: () => notifier.rotateSelected(90),
                onDuplicateSelected: () => notifier.duplicateSelected(),
                onDeleteSelected: () => _confirmDelete(context, notifier),
                onExtractSelected: () => _handleExtract(context, notifier, filePicker),
              ),
      ),
    );
  }

  Future<void> _handleApplyChanges(
    BuildContext context,
    PageOrganizerNotifier notifier,
  ) async {
    final success = await notifier.applyChanges();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
              ? 'Changes safely saved to PDF document!'
              : 'Failed to save changes.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  void _confirmDiscard(BuildContext context, PageOrganizerNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Workspace Changes?'),
        content: const Text(
          'You have uncommitted modifications to this document. Discarding will revert the workspace to the original file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.cancelChanges();
              Navigator.of(context).pop();
            },
            child: const Text('Discard Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PageOrganizerNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Selected Pages?'),
        content: const Text(
          'Remove selected pages from the workspace? Changes will only take effect on the PDF file once you tap "Apply Changes".',
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
            child: const Text('Remove'),
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

class _OrganizerGrid extends StatelessWidget {
  final String documentPath;
  final List<PageItem> pages;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onToggleSelect;
  final void Function(int index) onRotate;

  const _OrganizerGrid({
    required this.documentPath,
    required this.pages,
    required this.onReorder,
    required this.onToggleSelect,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: pages.length,
      itemBuilder: (context, index) {
        final item = pages[index];
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) => onReorder(details.data, index),
          builder: (context, candidateData, rejectedData) {
            final isTarget = candidateData.isNotEmpty;
            return LongPressDraggable<int>(
              data: index,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 140,
                  height: 190,
                  child: _PageCard(
                    documentPath: documentPath,
                    item: item,
                    index: index,
                    onToggleSelect: () {},
                    onRotate: () {},
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _PageCard(
                  documentPath: documentPath,
                  item: item,
                  index: index,
                  onToggleSelect: () => onToggleSelect(index),
                  onRotate: () => onRotate(index),
                ),
              ),
              child: Container(
                decoration: isTarget
                    ? BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: _PageCard(
                  documentPath: documentPath,
                  item: item,
                  index: index,
                  onToggleSelect: () => onToggleSelect(index),
                  onRotate: () => onRotate(index),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  final String documentPath;
  final PageItem item;
  final int index;
  final VoidCallback onToggleSelect;
  final VoidCallback onRotate;

  const _PageCard({
    required this.documentPath,
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
                    // Real Asynchronously Rendered Page Thumbnail
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: PdfPageThumbnailView(
                          documentPath: documentPath,
                          pageNumber: item.originalPageNumber,
                          rotationDegrees: item.rotationDegrees,
                          width: 130,
                          height: 180,
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black54 : Colors.white70),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.rotate_right, size: 20),
                          tooltip: 'Rotate 90°',
                          onPressed: onRotate,
                        ),
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
                    'Page ${item.originalPageNumber}',
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
  final VoidCallback onDuplicateSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onExtractSelected;

  const _OrganizerBottomBar({
    required this.selectedCount,
    required this.onRotateSelected,
    required this.onDuplicateSelected,
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
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Duplicate Selected',
              onPressed: onDuplicateSelected,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Extract to New PDF',
              onPressed: onExtractSelected,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Remove Selected',
              onPressed: onDeleteSelected,
            ),
          ],
        ),
      ),
    );
  }
}
