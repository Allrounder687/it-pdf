import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/document_meta.dart';
import '../../library/domain/library_notifier.dart';
import '../../reader/domain/document_tabs_notifier.dart';
import '../../reader/domain/reader_notifier.dart';
import '../../reader/presentation/reader_screen.dart';

/// Clean, minimal Home Screen showing Continue Reading, Recents and Favorites.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryNotifierProvider);
    final notifier = ref.read(libraryNotifierProvider.notifier);

    final recents = state.recentDocuments;
    final continueDoc = recents.isNotEmpty ? recents.first : null;
    final otherRecents = recents.length > 1
        ? recents.sublist(1)
        : <DocumentMeta>[];
    final favorites = state.favoriteDocuments;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(
              'IT PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.file_open_outlined, size: 18),
            label: const Text('Open PDF'),
            onPressed: () => notifier.pickAndImportPdf(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: recents.isEmpty
          ? _EmptyHomeView(onPickPdf: () => notifier.pickAndImportPdf())
          : RefreshIndicator(
              onRefresh: () => notifier.loadLibrary(),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // Continue Reading Hero Card
                  if (continueDoc != null) ...[
                    const Text(
                      'Continue Reading',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ContinueReadingCard(
                      doc: continueDoc,
                      onOpen: () => _openDocument(context, ref, continueDoc),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recent Documents Section
                  if (otherRecents.isNotEmpty) ...[
                    const Text(
                      'Recent Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherRecents.map(
                      (doc) => _RecentDocListTile(
                        doc: doc,
                        onOpen: () => _openDocument(context, ref, doc),
                        onToggleFavorite: () => notifier.toggleFavorite(doc.id),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Favorites Section
                  if (favorites.isNotEmpty) ...[
                    const Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...favorites.map(
                      (doc) => _RecentDocListTile(
                        doc: doc,
                        onOpen: () => _openDocument(context, ref, doc),
                        onToggleFavorite: () => notifier.toggleFavorite(doc.id),
                      ),
                    ),
                  ],
                ],
              ),
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
}

class _ContinueReadingCard extends StatelessWidget {
  final DocumentMeta doc;
  final VoidCallback onOpen;

  const _ContinueReadingCard({required this.doc, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final progress = doc.totalPages > 0
        ? (doc.lastPageRead / doc.totalPages).clamp(0.0, 1.0)
        : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F30) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.blue.shade100,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.blueAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${doc.lastPageRead} of ${doc.totalPages} • ${doc.formattedSize}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(
                          Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDocListTile extends StatelessWidget {
  final DocumentMeta doc;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  const _RecentDocListTile({
    required this.doc,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(
          Icons.picture_as_pdf_outlined,
          color: Colors.redAccent,
        ),
        title: Text(
          doc.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Page ${doc.lastPageRead}/${doc.totalPages} • ${doc.formattedSize}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            doc.isFavorite ? Icons.star : Icons.star_border,
            color: doc.isFavorite ? Colors.amber : Colors.grey,
            size: 20,
          ),
          onPressed: onToggleFavorite,
        ),
      ),
    );
  }
}

class _EmptyHomeView extends StatelessWidget {
  final VoidCallback onPickPdf;

  const _EmptyHomeView({required this.onPickPdf});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              size: 72,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Documents Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a PDF to start reading, annotating and organizing with zero distractions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Open PDF File'),
              onPressed: onPickPdf,
            ),
          ],
        ),
      ),
    );
  }
}
