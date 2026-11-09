import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Representation of an outline / bookmark entry with destination coordinate metadata.
class OutlineItem {
  final String title;
  final int targetPage;
  final PdfDest? dest;
  final int level;

  const OutlineItem({
    required this.title,
    required this.targetPage,
    this.dest,
    this.level = 0,
  });
}

/// Navigation drawer for browsing hierarchical document bookmarks & outline.
class OutlineDrawer extends StatelessWidget {
  final List<OutlineItem> outline;
  final ValueChanged<OutlineItem> onSelect;
  final int currentPage;

  const OutlineDrawer({
    super.key,
    required this.outline,
    required this.onSelect,
    this.currentPage = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.bookmarks_outlined, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Table of Contents',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: outline.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Table of Contents',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'This PDF document does not contain embedded bookmarks or outline metadata.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: outline.length,
                      itemBuilder: (context, index) {
                        final entry = outline[index];
                        final indent = (entry.level * 16.0).clamp(0.0, 80.0);
                        final isCurrentPage = entry.targetPage == currentPage;

                        return Material(
                          color: isCurrentPage
                              ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelect(entry);
                            },
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16 + indent, 10, 16, 10),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.level == 0 ? Icons.folder_open : Icons.article_outlined,
                                    size: 16,
                                    color: isCurrentPage ? Colors.blueAccent : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      style: TextStyle(
                                        fontWeight: entry.level == 0 || isCurrentPage
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                        color: isCurrentPage ? Colors.blueAccent : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (entry.targetPage > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCurrentPage
                                            ? Colors.blueAccent.withValues(alpha: 0.2)
                                            : (isDark ? Colors.white12 : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'p. ${entry.targetPage}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                                          color: isCurrentPage ? Colors.blueAccent : Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
