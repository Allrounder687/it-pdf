import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../../shared/models/document_meta.dart';
import '../../editor/domain/tool_task_notifier.dart';
import '../../editor/presentation/tools/tool_preview_modal.dart';
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
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (isDesktop) {
      return const _DesktopToolsCommandCenter();
    }

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
                      'Page ${doc.lastPageRead} of ${doc.totalPages} â€¢ ${doc.formattedSize}',
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
          'Page ${doc.lastPageRead}/${doc.totalPages} â€¢ ${doc.formattedSize}',
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

/// Strictly monochrome (Black / White / Gray) Desktop Tools Command Center
/// with status colors (Yellow = Running, Green = Completed, Red = Error),
/// click-to-preview popups, dockable multi-task tray, and top-right toasts.
class _DesktopToolsCommandCenter extends ConsumerStatefulWidget {
  const _DesktopToolsCommandCenter();

  @override
  ConsumerState<_DesktopToolsCommandCenter> createState() =>
      _DesktopToolsCommandCenterState();
}

class _DesktopToolsCommandCenterState
    extends ConsumerState<_DesktopToolsCommandCenter> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ToolCategory _selectedCategory = ToolCategory.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openToolPreview(PdfTool tool) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => ToolPreviewModal(
        tool: tool,
        onMinimizeToTray: () {
          ref
              .read(toolTaskManagerProvider.notifier)
              .startTask(
                toolId: tool.id,
                toolTitle: tool.title,
                toolIcon: tool.icon,
                initialMessage: 'Ready & docked in Task Tray â€” tap to resume',
              );
          Navigator.of(dialogCtx).pop();
        },
        onOpenFullscreen: () => _runTrackedTool(tool),
      ),
    );
  }

  Future<void> _runTrackedTool(PdfTool tool) async {
    final taskNotifier = ref.read(toolTaskManagerProvider.notifier);
    final task = taskNotifier.startTask(
      toolId: tool.id,
      toolTitle: tool.title,
      toolIcon: tool.icon,
      initialMessage: 'Running ${tool.title}...',
    );

    try {
      await tool.execute(context, ref);
      taskNotifier.completeTask(
        task.id,
        outputPath: '',
        message: '${tool.title} finished cleanly.',
      );
    } catch (e) {
      taskNotifier.failTask(task.id, error: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasks = ref.watch(toolTaskManagerProvider);
    final notifications = ref.watch(inAppNotificationsProvider);

    // 3-Color Strict Palette: Obsidian Black / Crisp White / Neutral Slate Gray
    final canvasBg = isDark ? const Color(0xFF090B10) : const Color(0xFFF8FAFC);
    final surfaceBg = isDark ? const Color(0xFF11141C) : Colors.white;
    final borderCol = isDark
        ? const Color(0xFF222733)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final query = _searchQuery.trim().toLowerCase();
    final filteredTools = registeredPdfTools.where((tool) {
      final matchesCategory =
          _selectedCategory == ToolCategory.all ||
          tool.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return tool.title.toLowerCase().contains(query) ||
          tool.description.toLowerCase().contains(query) ||
          tool.searchKeywords.any((k) => k.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: canvasBg,
      body: Stack(
        children: [
          Column(
            children: [
              // Clean Monochrome Studio Header
              Container(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  border: Border(bottom: BorderSide(color: borderCol)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1F2B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderCol),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 20,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IT PDF Tools Studio',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Select any tool to preview capabilities, run concurrently, or launch fullscreen.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Search Input
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText:
                                  'Search ${registeredPdfTools.length} tools...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: canvasBg,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: textPrimary,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Monochrome Category Filter Strip
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ToolCategory.values.map((cat) {
                          final selected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: selected ? textPrimary : canvasBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected ? textPrimary : borderCol,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat.icon,
                                      size: 14,
                                      color: selected
                                          ? canvasBg
                                          : textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? canvasBg
                                            : textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Main All-Tools Grid Canvas
              Expanded(
                child: filteredTools.isEmpty
                    ? Center(
                        child: Text(
                          'No tools match "$_searchQuery".',
                          style: TextStyle(color: textSecondary, fontSize: 14),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          24,
                          28,
                          tasks.isNotEmpty ? 96 : 28,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 340,
                              mainAxisExtent: 162,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: filteredTools.length,
                        itemBuilder: (context, index) {
                          final tool = filteredTools[index];
                          final activeTask = tasks.cast<ToolTask?>().firstWhere(
                            (t) => t?.toolId == tool.id,
                            orElse: () => null,
                          );
                          return _DesktopToolCard(
                            tool: tool,
                            activeTask: activeTask,
                            isDark: isDark,
                            surfaceBg: surfaceBg,
                            borderCol: borderCol,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => _openToolPreview(tool),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Docked Concurrent Multi-Task Tray at Bottom
          if (tasks.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: _DesktopTaskTray(
                tasks: tasks,
                isDark: isDark,
                surfaceBg: surfaceBg,
                borderCol: borderCol,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onRestoreTool: (toolId) {
                  final tool = registeredPdfTools.cast<PdfTool?>().firstWhere(
                    (t) => t?.id == toolId,
                    orElse: () => null,
                  );
                  if (tool != null) {
                    _openToolPreview(tool);
                  }
                },
                onDismissTask: (id) =>
                    ref.read(toolTaskManagerProvider.notifier).dismissTask(id),
                onClearCompleted: () =>
                    ref.read(toolTaskManagerProvider.notifier).clearCompleted(),
              ),
            ),

          // Top-Right Non-Intrusive Status Toast Overlay
          if (notifications.isNotEmpty)
            Positioned(
              top: 16,
              right: 20,
              child: _TopRightNotificationsOverlay(
                notifications: notifications,
                isDark: isDark,
                onDismiss: (id) =>
                    ref.read(inAppNotificationsProvider.notifier).dismiss(id),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopToolCard extends StatefulWidget {
  final PdfTool tool;
  final ToolTask? activeTask;
  final bool isDark;
  final Color surfaceBg;
  final Color borderCol;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _DesktopToolCard({
    required this.tool,
    required this.activeTask,
    required this.isDark,
    required this.surfaceBg,
    required this.borderCol,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  State<_DesktopToolCard> createState() => _DesktopToolCardState();
}

class _DesktopToolCardState extends State<_DesktopToolCard> {
  bool _hovered = false;

  Color? get _statusAccent {
    switch (widget.activeTask?.status) {
      case ToolTaskStatus.running:
        return const Color(0xFFEAB308); // Yellow / Amber
      case ToolTaskStatus.completed:
        return const Color(0xFF10B981); // Green
      case ToolTaskStatus.error:
        return const Color(0xFFEF4444); // Red
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusAccent;
    final cardBorderColor = statusColor != null
        ? statusColor.withAlpha(_hovered ? 220 : 150)
        : (_hovered ? widget.textPrimary.withAlpha(140) : widget.borderCol);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cardBorderColor,
              width: statusColor != null || _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: (statusColor ?? Colors.black).withAlpha(
                        widget.isDark ? 40 : 15,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1A1F2B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.borderCol),
                    ),
                    child: Icon(
                      widget.tool.icon,
                      size: 20,
                      color: statusColor ?? widget.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (statusColor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withAlpha(120)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.activeTask!.status == ToolTaskStatus.running
                                ? 'RUNNING'
                                : (widget.activeTask!.status ==
                                          ToolTaskStatus.completed
                                      ? 'DONE'
                                      : 'ERROR'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF1A1F2B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.tool.badge ?? widget.tool.category.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: widget.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.tool.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.textPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  widget.tool.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTaskTray extends StatelessWidget {
  final List<ToolTask> tasks;
  final bool isDark;
  final Color surfaceBg;
  final Color borderCol;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<String> onRestoreTool;
  final ValueChanged<String> onDismissTask;
  final VoidCallback onClearCompleted;

  const _DesktopTaskTray({
    required this.tasks,
    required this.isDark,
    required this.surfaceBg,
    required this.borderCol,
    required this.textPrimary,
    required this.textSecondary,
    required this.onRestoreTool,
    required this.onDismissTask,
    required this.onClearCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceBg.withAlpha(245),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 90 : 25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, size: 16, color: textSecondary),
              const SizedBox(width: 6),
              Text(
                'TASK TRAY (${tasks.length})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          VerticalDivider(color: borderCol, width: 1),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                Color statusCol;
                IconData statusIcon;
                switch (task.status) {
                  case ToolTaskStatus.running:
                    statusCol = const Color(0xFFEAB308);
                    statusIcon = Icons.sync_rounded;
                    break;
                  case ToolTaskStatus.completed:
                    statusCol = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle_rounded;
                    break;
                  case ToolTaskStatus.error:
                    statusCol = const Color(0xFFEF4444);
                    statusIcon = Icons.error_rounded;
                    break;
                  case ToolTaskStatus.idle:
                    statusCol = textSecondary;
                    statusIcon = Icons.hourglass_empty_rounded;
                    break;
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onRestoreTool(task.toolId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: statusCol.withAlpha(22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusCol.withAlpha(110)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusCol),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            task.toolTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => onDismissTask(task.id),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClearCompleted,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: textSecondary,
            ),
            child: const Text('Clear Done', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _TopRightNotificationsOverlay extends StatelessWidget {
  final List<InAppNotification> notifications;
  final bool isDark;
  final ValueChanged<String> onDismiss;

  const _TopRightNotificationsOverlay({
    required this.notifications,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: notifications.take(3).map((notif) {
        final statusColor = notif.status == ToolTaskStatus.completed
            ? const Color(0xFF10B981)
            : (notif.status == ToolTaskStatus.error
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFEAB308));
        final icon = notif.status == ToolTaskStatus.completed
            ? Icons.check_circle_rounded
            : (notif.status == ToolTaskStatus.error
                  ? Icons.error_rounded
                  : Icons.info_rounded);

        return Container(
          width: 310,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111622) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withAlpha(140), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 90 : 30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => onDismiss(notif.id),
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
