import 'package:flutter/material.dart';
import '../domain/reader_state.dart';
import 'reader_view_controls.dart';

/// Responsive master top AppBar for IT PDF.
/// Seamlessly adapts between desktop/tablet full controls and mobile compact action overflow.
class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String documentName;
  final int currentPage;
  final int pageCount;
  final double currentZoom;
  final ReaderLayout currentLayout;
  final ReaderThemeMode themeMode;
  final bool isToolActive;
  final bool hasAnnotations;
  final bool isSearchActive;
  final bool isSearchReady;
  final bool showThumbnails;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<double> onSelectZoom;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final ValueChanged<ReaderLayout> onSelectLayout;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onOpenOutline;
  final VoidCallback onOpenAiAssistant;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleThumbnails;
  final VoidCallback onCycleTheme;
  final VoidCallback onToggleAnnotations;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onOpenOrganizer;
  final VoidCallback onOpenForms;
  final VoidCallback onOpenProtect;

  const ReaderAppBar({
    super.key,
    required this.documentName,
    required this.currentPage,
    required this.pageCount,
    required this.currentZoom,
    required this.currentLayout,
    required this.themeMode,
    required this.isToolActive,
    required this.hasAnnotations,
    required this.isSearchActive,
    required this.isSearchReady,
    required this.showThumbnails,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSelectZoom,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onSelectLayout,
    required this.onJumpToPage,
    required this.onOpenOutline,
    required this.onOpenAiAssistant,
    required this.onToggleSearch,
    required this.onToggleThumbnails,
    required this.onCycleTheme,
    required this.onToggleAnnotations,
    required this.onSaveAnnotations,
    required this.onOpenOrganizer,
    required this.onOpenForms,
    required this.onOpenProtect,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    return AppBar(
      title: Text(
        documentName,
        style: TextStyle(
          fontSize: isCompact ? 14 : 15,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: isCompact
          ? _buildMobileActions(context)
          : _buildDesktopActions(context),
    );
  }

  List<Widget> _buildMobileActions(BuildContext context) {
    return [
      // Page jump pill for quick navigation on mobile
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showJumpDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currentPage / $pageCount',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Icon(Icons.arrow_drop_down, size: 14),
            ],
          ),
        ),
      ),

      // In-document Search Trigger
      IconButton(
        icon: Icon(
          Icons.search,
          color: isSearchActive ? Colors.blueAccent : null,
          size: 20,
        ),
        tooltip: 'Search',
        onPressed: () {
          if (!isSearchReady) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document is still loading... Please wait.'),
                duration: Duration(seconds: 1),
              ),
            );
            return;
          }
          onToggleSearch();
        },
      ),

      // Reading Theme Mode
      IconButton(
        icon: Icon(_getThemeIcon(), size: 20),
        tooltip: 'Theme',
        onPressed: onCycleTheme,
      ),

      // Annotation Toggle (Direct access)
      IconButton(
        icon: Icon(
          Icons.edit_note,
          color: isToolActive ? Colors.blueAccent : null,
          size: 20,
        ),
        tooltip: 'Annotate',
        onPressed: onToggleAnnotations,
      ),

      // Overflow Menu with All Extended Capabilities
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (val) {
          switch (val) {
            case 'toc':
              onOpenOutline();
              break;
            case 'ai':
              onOpenAiAssistant();
              break;
            case 'thumbnails':
              onToggleThumbnails();
              break;
            case 'save':
              onSaveAnnotations();
              break;
            case 'fit_width':
              onFitWidth();
              break;
            case 'fit_page':
              onFitPage();
              break;
            case 'organizer':
              onOpenOrganizer();
              break;
            case 'forms':
              onOpenForms();
              break;
            case 'protect':
              onOpenProtect();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'toc',
            child: Row(
              children: [
                Icon(Icons.bookmarks_outlined, size: 18),
                SizedBox(width: 8),
                Text('Table of Contents'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'ai',
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 18),
                SizedBox(width: 8),
                Text('AI Assistant'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'thumbnails',
            child: Row(
              children: [
                Icon(Icons.view_carousel_outlined,
                    color: showThumbnails ? Colors.blueAccent : null, size: 18),
                const SizedBox(width: 8),
                const Text('Thumbnails Strip'),
              ],
            ),
          ),
          if (hasAnnotations)
            const PopupMenuItem(
              value: 'save',
              child: Row(
                children: [
                  Icon(Icons.save_outlined, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Burn & Save Annotations'),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'fit_width',
            child: Row(
              children: [
                Icon(Icons.fit_screen, size: 18),
                SizedBox(width: 8),
                Text('Fit to Width'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'fit_page',
            child: Row(
              children: [
                Icon(Icons.fullscreen, size: 18),
                SizedBox(width: 8),
                Text('Fit Whole Page'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'organizer',
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 18),
                SizedBox(width: 8),
                Text('Page Organizer'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'forms',
            child: Row(
              children: [
                Icon(Icons.format_shapes, size: 18),
                SizedBox(width: 8),
                Text('Interactive Forms'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'protect',
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Text('Password Protect'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildDesktopActions(BuildContext context) {
    return [
      // View Scaling & Page Navigation Toolbar
      ReaderViewControls(
        currentPage: currentPage,
        pageCount: pageCount,
        currentZoom: currentZoom,
        currentLayout: currentLayout,
        onZoomIn: onZoomIn,
        onZoomOut: onZoomOut,
        onSelectZoom: onSelectZoom,
        onFitWidth: onFitWidth,
        onFitPage: onFitPage,
        onSelectLayout: onSelectLayout,
        onJumpToPage: onJumpToPage,
      ),

      const VerticalDivider(width: 16, indent: 12, endIndent: 12),

      // Table of Contents Drawer Trigger
      IconButton(
        icon: const Icon(Icons.bookmarks_outlined),
        tooltip: 'Table of Contents',
        onPressed: onOpenOutline,
      ),

      // Grounded AI Assistant Drawer
      IconButton(
        icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
        tooltip: 'AI Document Assistant',
        onPressed: onOpenAiAssistant,
      ),

      // In-document Search Toggle
      IconButton(
        icon: Icon(
          Icons.search,
          color: isSearchActive ? Colors.blueAccent : null,
        ),
        tooltip: 'Search (Ctrl+F)',
        onPressed: () {
          if (!isSearchReady) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document is still loading... Please wait.'),
                duration: Duration(seconds: 1),
              ),
            );
            return;
          }
          onToggleSearch();
        },
      ),

      // Thumbnail Strip Toggle
      IconButton(
        icon: Icon(
          Icons.view_carousel_outlined,
          color: showThumbnails ? Colors.blueAccent : null,
        ),
        tooltip: 'Thumbnails',
        onPressed: onToggleThumbnails,
      ),

      // Reading Theme Toggle
      IconButton(
        icon: Icon(_getThemeIcon()),
        tooltip: 'Reading Theme',
        onPressed: onCycleTheme,
      ),

      // Annotation Mode Toggle
      IconButton(
        icon: Icon(
          Icons.edit_note,
          color: isToolActive ? Colors.blueAccent : null,
        ),
        tooltip: 'Annotate',
        onPressed: onToggleAnnotations,
      ),

      // Save & Burn Annotations to PDF
      if (hasAnnotations)
        IconButton(
          icon: const Icon(Icons.save_outlined, color: Colors.green),
          tooltip: 'Burn & Save Annotations (Ctrl+S)',
          onPressed: onSaveAnnotations,
        ),

      // More Actions: Forms, Security, Page Organizer
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (val) {
          if (val == 'organizer') {
            onOpenOrganizer();
          } else if (val == 'forms') {
            onOpenForms();
          } else if (val == 'protect') {
            onOpenProtect();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'organizer',
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 18),
                SizedBox(width: 8),
                Text('Page Organizer'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'forms',
            child: Row(
              children: [
                Icon(Icons.format_shapes, size: 18),
                SizedBox(width: 8),
                Text('Interactive Forms'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'protect',
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Text('Password Protect'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  IconData _getThemeIcon() {
    switch (themeMode) {
      case ReaderThemeMode.sepia:
        return Icons.auto_stories;
      case ReaderThemeMode.dark:
      case ReaderThemeMode.night:
        return Icons.dark_mode;
      case ReaderThemeMode.light:
        return Icons.light_mode;
    }
  }

  void _showJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: '$currentPage');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $pageCount)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final page = int.tryParse(val);
            if (page != null && page >= 1 && page <= pageCount) {
              Navigator.of(ctx).pop();
              onJumpToPage(page);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= pageCount) {
                Navigator.of(ctx).pop();
                onJumpToPage(page);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
}
