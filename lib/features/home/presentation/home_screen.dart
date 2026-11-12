import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../../shared/models/document_meta.dart';
import '../../editor/presentation/tools/tools_registry.dart';
import '../../editor/presentation/tools_screen.dart';
import '../../library/domain/library_notifier.dart';
import '../../reader/domain/document_tabs_notifier.dart';
import '../../reader/domain/reader_notifier.dart';
import '../../reader/presentation/reader_screen.dart';

/// Clean, friendly Home Screen showing Quick Tools, Continue Reading, Recents and Favorites.
/// Inspired by modern consumer PDF suites (Smallpdf) with warm, intuitive visual cues.
class HomeScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToTools;

  const HomeScreen({super.key, this.onNavigateToTools});

  void _navigateToTools(BuildContext context) {
    if (onNavigateToTools != null) {
      onNavigateToTools!();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ToolsScreen()));
    }
  }

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark
        ? AppTheme.primaryBlueDark
        : AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: accentColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'IT PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.file_open_outlined, size: 16),
            label: const Text('Open PDF'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => notifier.pickAndImportPdf(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: recents.isEmpty
          ? _EmptyHomeView(
              onPickPdf: () => notifier.pickAndImportPdf(),
              onNavigateToTools: () => _navigateToTools(context),
            )
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
                    const SizedBox(height: 20),
                  ],

                  // Smallpdf-style Quick Tools Row
                  _QuickToolsRow(onSeeAll: () => _navigateToTools(context)),
                  const SizedBox(height: 24),

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

/// Smallpdf-style quick tools row backed directly by individual modular tools
class _QuickToolsRow extends ConsumerWidget {
  final VoidCallback onSeeAll;

  const _QuickToolsRow({required this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Tools',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View All Tools'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popularPdfTools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final tool = popularPdfTools[index];
              return _QuickToolCard(
                title: tool.title,
                subtitle: tool.badge ?? tool.category.label,
                icon: tool.icon,
                color: tool.color,
                onTap: () => tool.execute(context, ref),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickToolCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickToolCard> createState() => _QuickToolCardState();
}

class _QuickToolCardState extends State<_QuickToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? widget.color.withValues(alpha: _isHovered ? 0.22 : 0.12)
        : widget.color.withValues(alpha: _isHovered ? 0.16 : 0.08);
    final borderColor = widget.color.withValues(alpha: _isHovered ? 0.6 : 0.25);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 168,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 62,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceVariant
                      : AppTheme.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: PdfPageThumbnailView(
                  documentPath: doc.path,
                  pageNumber: 1,
                  width: 48,
                  height: 62,
                  placeholder: Icon(
                    Icons.menu_book_rounded,
                    color: isDark
                        ? AppTheme.primaryBlueDark
                        : AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${doc.lastPageRead} of ${doc.totalPages} • ${doc.formattedSize}',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(
                          isDark
                              ? AppTheme.primaryBlueDark
                              : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
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
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 36,
            height: 46,
            child: PdfPageThumbnailView(
              documentPath: doc.path,
              pageNumber: 1,
              width: 36,
              height: 46,
              placeholder: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.redAccent,
              ),
            ),
          ),
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

class _EmptyHomeView extends ConsumerWidget {
  final VoidCallback onPickPdf;
  final VoidCallback onNavigateToTools;

  const _EmptyHomeView({
    required this.onPickPdf,
    required this.onNavigateToTools,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark
        ? AppTheme.primaryBlueDark
        : AppTheme.primaryBlue;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Friendly Dropzone Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 30,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Documents Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open a PDF to start reading, annotating and organizing with zero distractions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      icon: const Icon(Icons.file_open, size: 16),
                      label: const Text('Open PDF File'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onPickPdf,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Smallpdf-style "Popular Tools" Launchpad (never overflows narrow viewports)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Popular Tools',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onNavigateToTools,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('All Tools'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _PopularToolTile(
                      title: popularPdfTools[0].title,
                      subtitle: popularPdfTools[0].category.label,
                      icon: popularPdfTools[0].icon,
                      color: popularPdfTools[0].color,
                      onTap: () => popularPdfTools[0].execute(context, ref),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PopularToolTile(
                      title: popularPdfTools[1].title,
                      subtitle: popularPdfTools[1].category.label,
                      icon: popularPdfTools[1].icon,
                      color: popularPdfTools[1].color,
                      onTap: () => popularPdfTools[1].execute(context, ref),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PopularToolTile(
                      title: popularPdfTools[2].title,
                      subtitle: popularPdfTools[2].category.label,
                      icon: popularPdfTools[2].icon,
                      color: popularPdfTools[2].color,
                      onTap: () => popularPdfTools[2].execute(context, ref),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PopularToolTile(
                      title: popularPdfTools[3].title,
                      subtitle: popularPdfTools[3].category.label,
                      icon: popularPdfTools[3].icon,
                      color: popularPdfTools[3].color,
                      onTap: () => popularPdfTools[3].execute(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularToolTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PopularToolTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PopularToolTile> createState() => _PopularToolTileState();
}

class _PopularToolTileState extends State<_PopularToolTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? widget.color.withValues(alpha: _isHovered ? 0.22 : 0.12)
        : widget.color.withValues(alpha: _isHovered ? 0.16 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.color.withValues(alpha: _isHovered ? 0.6 : 0.25),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
