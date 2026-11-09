import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../annotations/domain/annotation_model.dart';
import '../../annotations/domain/annotation_notifier.dart';
import '../../annotations/presentation/annotation_overlay.dart';
import '../../annotations/presentation/annotation_toolbar.dart';
import '../../page_organizer/domain/page_organizer_notifier.dart';
import '../../page_organizer/presentation/page_organizer_screen.dart';
import '../domain/reader_notifier.dart';
import '../domain/reader_state.dart';

/// Master PDF Reader Viewport screen powered by PDFium via pdfrx.
class ReaderScreen extends ConsumerStatefulWidget {
  final ReaderNotifierParams params;

  const ReaderScreen({
    super.key,
    required this.params,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PdfViewerController _pdfController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerNotifierProvider(widget.params));
    final notifier = ref.read(readerNotifierProvider(widget.params).notifier);
    final annotationState = ref.watch(annotationNotifierProvider(widget.params.id));
    final isToolActive = annotationState.activeTool != AnnotationTool.none;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: readerState.showControls
          ? AppBar(
              title: Text(
                readerState.documentName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // In-document Search Toggle
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: readerState.showSearch ? Colors.blueAccent : null,
                  ),
                  tooltip: 'Search Document',
                  onPressed: () => notifier.toggleSearch(),
                ),

                // Reading Theme Toggle (Light / Dark / Sepia)
                IconButton(
                  icon: Icon(
                    readerState.themeMode == ReaderThemeMode.sepia
                        ? Icons.auto_stories
                        : (readerState.themeMode == ReaderThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode),
                  ),
                  tooltip: 'Reading Theme',
                  onPressed: () => _cycleReadingTheme(readerState, notifier),
                ),

                // Annotation Mode Toggle
                IconButton(
                  icon: Icon(
                    Icons.edit_note,
                    color: isToolActive ? Colors.blueAccent : null,
                  ),
                  tooltip: 'Annotate',
                  onPressed: () {
                    final annNotifier =
                        ref.read(annotationNotifierProvider(widget.params.id).notifier);
                    if (isToolActive) {
                      annNotifier.setActiveTool(AnnotationTool.none);
                    } else {
                      annNotifier.setActiveTool(AnnotationTool.pen);
                    }
                  },
                ),

                // Page Organizer Action
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  tooltip: 'Page Organizer',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PageOrganizerScreen(
                          params: PageOrganizerParams(
                            path: readerState.documentPath,
                            id: readerState.documentId,
                            name: readerState.documentName,
                            pageCount: readerState.pageCount,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Main PDFium Viewport
          GestureDetector(
            onTap: () {
              if (!isToolActive) {
                notifier.toggleControls();
              }
            },
            child: _applyReadingFilter(
              themeMode: readerState.themeMode,
              child: PdfViewer.file(
                readerState.documentPath,
                controller: _pdfController,
                params: PdfViewerParams(
                  onDocumentChanged: (document) {
                    if (document != null) {
                      notifier.setPageCount(document.pages.length);
                    }
                  },
                  onPageChanged: (page) {
                    if (page != null) {
                      notifier.setPage(page);
                    }
                  },
                  pageOverlaysBuilder: (context, pageRect, page) {
                    return [
                      AnnotationOverlay(
                        documentId: widget.params.id,
                        pageNumber: page.pageNumber,
                        pageSize: Size(pageRect.width, pageRect.height),
                      ),
                    ];
                  },
                ),
              ),
            ),
          ),

          // Contextual In-Document Search Overlay Bar
          if (readerState.showSearch)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _SearchBarOverlay(
                controller: _searchController,
                onClose: () => notifier.toggleSearch(),
                onSearch: (q) => notifier.setSearchQuery(q),
              ),
            ),

          // Annotation Floating Toolbar
          if (isToolActive)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Center(
                child: AnnotationToolbar(documentId: widget.params.id),
              ),
            ),

          // Bottom Reading Position Indicator Pill
          if (readerState.showControls && !isToolActive)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Page ${readerState.currentPage} of ${readerState.pageCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _cycleReadingTheme(ReaderState state, ReaderNotifier notifier) {
    switch (state.themeMode) {
      case ReaderThemeMode.light:
        notifier.setThemeMode(ReaderThemeMode.dark);
        break;
      case ReaderThemeMode.dark:
        notifier.setThemeMode(ReaderThemeMode.sepia);
        break;
      case ReaderThemeMode.sepia:
      case ReaderThemeMode.night:
        notifier.setThemeMode(ReaderThemeMode.light);
        break;
    }
  }

  Widget _applyReadingFilter({
    required ReaderThemeMode themeMode,
    required Widget child,
  }) {
    switch (themeMode) {
      case ReaderThemeMode.dark:
      case ReaderThemeMode.night:
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -1.0, 0, 0, 0, 255, // red
            0, -1.0, 0, 0, 255, // green
            0, 0, -1.0, 0, 255, // blue
            0, 0, 0, 1.0, 0, // alpha
          ]),
          child: child,
        );
      case ReaderThemeMode.sepia:
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.9, 0, 0, 0, 40,
            0, 0.85, 0, 0, 30,
            0, 0, 0.75, 0, 10,
            0, 0, 0, 1.0, 0,
          ]),
          child: child,
        );
      case ReaderThemeMode.light:
        return child;
    }
  }
}

class _SearchBarOverlay extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onSearch;

  const _SearchBarOverlay({
    required this.controller,
    required this.onClose,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search text in document...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onSearch,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
