import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/document_meta.dart';
import '../domain/library_notifier.dart';
import '../domain/library_state.dart';
import '../../reader/domain/document_tabs_notifier.dart';
import '../../reader/domain/reader_notifier.dart';
import '../../reader/presentation/reader_screen.dart';

/// Full document management library with folders, grid/list view, sorting and multi-select.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryNotifierProvider);
    final notifier = ref.read(libraryNotifierProvider.notifier);
    final isMultiSelect = state.selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: isMultiSelect
            ? Text('${state.selectedIds.length} Selected')
            : const Text(
                'Document Library',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: isMultiSelect
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () => notifier.selectAll(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Delete Selected',
                  onPressed: () => _confirmBatchDelete(context, notifier),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel Selection',
                  onPressed: () => notifier.clearSelection(),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(
                    state.isGridView ? Icons.view_list : Icons.grid_view,
                  ),
                  tooltip: state.isGridView ? 'List View' : 'Grid View',
                  onPressed: () => notifier.toggleViewMode(),
                ),
                PopupMenuButton<LibrarySortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort by',
                  onSelected: (option) => notifier.setSortOption(option),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: LibrarySortOption.lastOpened,
                      child: Text('Last Opened'),
                    ),
                    const PopupMenuItem(
                      value: LibrarySortOption.name,
                      child: Text('File Name'),
                    ),
                    const PopupMenuItem(
                      value: LibrarySortOption.size,
                      child: Text('File Size'),
                    ),
                    const PopupMenuItem(
                      value: LibrarySortOption.dateAdded,
                      child: Text('Date Added'),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Import PDF',
                  onPressed: () => notifier.pickAndImportPdf(),
                ),
              ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search documents by title or tags...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => notifier.setSearchQuery(''),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onChanged: (q) => notifier.setSearchQuery(q),
            ),
          ),

          // Folder Filter Chips
          if (state.availableFolders.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: state.filterFolder == null,
                    onSelected: (_) => notifier.setFilterFolder(null),
                  ),
                  const SizedBox(width: 8),
                  ...state.availableFolders.map(
                    (folder) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(folder),
                        selected: state.filterFolder == folder,
                        onSelected: (selected) =>
                            notifier.setFilterFolder(selected ? folder : null),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Documents Content
          Expanded(
            child: state.visibleDocuments.isEmpty
                ? const Center(
                    child: Text('No documents matching your filter.'),
                  )
                : state.isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: state.visibleDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = state.visibleDocuments[index];
                      final isSelected = state.selectedIds.contains(doc.id);
                      return _LibraryGridCard(
                        doc: doc,
                        isSelected: isSelected,
                        onTap: () {
                          if (isMultiSelect) {
                            notifier.toggleSelect(doc.id);
                          } else {
                            _openDocument(context, ref, doc);
                          }
                        },
                        onLongPress: () => notifier.toggleSelect(doc.id),
                        onMore: () =>
                            _showDocumentActions(context, doc, notifier),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.visibleDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = state.visibleDocuments[index];
                      final isSelected = state.selectedIds.contains(doc.id);
                      return _LibraryListTile(
                        doc: doc,
                        isSelected: isSelected,
                        onTap: () {
                          if (isMultiSelect) {
                            notifier.toggleSelect(doc.id);
                          } else {
                            _openDocument(context, ref, doc);
                          }
                        },
                        onLongPress: () => notifier.toggleSelect(doc.id),
                        onMore: () =>
                            _showDocumentActions(context, doc, notifier),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDocument(BuildContext context, WidgetRef ref, DocumentMeta doc) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (isDesktop) {
      ref.read(documentTabsNotifierProvider.notifier).openTab(doc);
    } else {
      Navigator.of(context).push(
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

  void _confirmBatchDelete(BuildContext context, LibraryNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete from Library?'),
        content: const Text(
          'Remove selected documents from IT PDF registry? Source files on your device will remain intact.',
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
              notifier.batchDeleteSelected(deleteSourceFile: false);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDocumentActions(
    BuildContext context,
    DocumentMeta doc,
    LibraryNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameDialog(context, doc, notifier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Set Folder'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showFolderDialog(context, doc, notifier);
              },
            ),
            ListTile(
              leading: Icon(
                doc.isFavorite ? Icons.star_border : Icons.star,
                color: Colors.amber,
              ),
              title: Text(
                doc.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.toggleFavorite(doc.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File Details'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showFileDetails(context, doc);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Remove from Library',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                notifier.deleteDocument(doc.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    DocumentMeta doc,
    LibraryNotifier notifier,
  ) {
    final controller = TextEditingController(text: doc.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.renameDocument(doc.id, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFolderDialog(
    BuildContext context,
    DocumentMeta doc,
    LibraryNotifier notifier,
  ) {
    final controller = TextEditingController(text: doc.folder ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name (e.g. Work, Taxes)',
            hintText: 'Leave empty for no folder',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.setFolder(doc.id, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFileDetails(BuildContext context, DocumentMeta doc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${doc.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Size: ${doc.formattedSize}'),
            const SizedBox(height: 4),
            Text('Pages: ${doc.totalPages}'),
            const SizedBox(height: 4),
            Text('Last Page Read: ${doc.lastPageRead}'),
            const SizedBox(height: 4),
            Text(
              'Path: ${doc.path}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  final DocumentMeta doc;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  const _LibraryGridCard({
    required this.doc,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.blueAccent
              : (isDark ? Colors.white12 : Colors.black12),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF131B2A) : Colors.grey.shade100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 44,
                      color: Colors.redAccent,
                    ),
                    if (isSelected)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.blueAccent,
                          size: 22,
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onPressed: onMore,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doc.formattedSize} • ${doc.totalPages}p',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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

class _LibraryListTile extends StatelessWidget {
  final DocumentMeta doc;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  const _LibraryListTile({
    required this.doc,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
        title: Text(
          doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${doc.formattedSize} • ${doc.totalPages} pages',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMore,
        ),
      ),
    );
  }
}
