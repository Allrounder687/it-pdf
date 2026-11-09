import 'package:flutter/material.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';

/// Navigation drawer for browsing hierarchical document bookmarks & outline.
class OutlineDrawer extends StatelessWidget {
  final List<PdfOutlineEntry> outline;
  final ValueChanged<int> onSelectPage;

  const OutlineDrawer({
    super.key,
    required this.outline,
    required this.onSelectPage,
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.bookmarks_outlined, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Table of Contents',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: outline.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No outline bookmarks found in this document.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: outline.length,
                      itemBuilder: (context, index) {
                        final entry = outline[index];
                        final indent = entry.level * 16.0;

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelectPage(entry.targetPage);
                          },
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16 + indent, 10, 16, 10),
                            child: Row(
                              children: [
                                Icon(
                                  entry.level == 0 ? Icons.folder_open : Icons.article_outlined,
                                  size: 16,
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: TextStyle(
                                      fontWeight: entry.level == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'p. ${entry.targetPage}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                              ],
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
