import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/providers.dart';
import '../../ai_assistant/presentation/ai_assistant_sheet.dart';
import '../../annotations/domain/annotation_model.dart';
import '../../annotations/domain/annotation_notifier.dart';
import '../../annotations/presentation/annotation_overlay.dart';
import '../../annotations/presentation/annotation_toolbar.dart';
import '../../forms/presentation/form_fields_dialog.dart';
import '../../page_organizer/domain/page_organizer_notifier.dart';
import '../../page_organizer/presentation/page_organizer_screen.dart';
import '../../security/presentation/password_protect_dialog.dart';
import '../domain/reader_notifier.dart';
import '../domain/reader_state.dart';
import 'outline_drawer.dart';
import 'reader_search_bar.dart';
import 'thumbnail_strip.dart';

/// Master PDF Reader Viewport screen powered by PDFium (pdfrx) and Syncfusion PDF Engine.
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
  late final PdfTextSearcher _searcher;
  List<PdfOutlineEntry> _outline = [];
  Map<int, String> _extractedPageTexts = {};
  bool _showThumbnails = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _searcher = PdfTextSearcher(_pdfController);
    _loadDocumentIntelligence();
  }

  Future<void> _loadDocumentIntelligence() async {
    final pdfService = ref.read(syncfusionPdfServiceProvider);
    try {
      final bookmarks = await pdfService.extractBookmarks(widget.params.path);
      final texts = await pdfService.extractDocumentText(widget.params.path);
      if (mounted) {
        setState(() {
          _outline = bookmarks;
          _extractedPageTexts = texts;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerNotifierProvider(widget.params));
    final notifier = ref.read(readerNotifierProvider(widget.params).notifier);
    final annotationState = ref.watch(annotationNotifierProvider(widget.params.id));
    final annNotifier = ref.read(annotationNotifierProvider(widget.params.id).notifier);
    final pdfService = ref.watch(syncfusionPdfServiceProvider);
    final filePicker = ref.watch(filePickerServiceProvider);

    final isToolActive = annotationState.activeTool != AnnotationTool.none;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): const _SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const _SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const _UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): const _RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const _PrevPageIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const _NextPageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) => _handleBurnAndSave(context, annNotifier)),
          _SearchIntent: CallbackAction<_SearchIntent>(onInvoke: (_) => notifier.toggleSearch()),
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) => annNotifier.undo()),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) => annNotifier.redo()),
          _PrevPageIntent: CallbackAction<_PrevPageIntent>(
            onInvoke: (_) => _goToPage((readerState.currentPage - 1).clamp(1, readerState.pageCount)),
          ),
          _NextPageIntent: CallbackAction<_NextPageIntent>(
            onInvoke: (_) => _goToPage((readerState.currentPage + 1).clamp(1, readerState.pageCount)),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            drawer: OutlineDrawer(
              outline: _outline,
              onSelectPage: (p) => _goToPage(p),
            ),
            appBar: readerState.showControls
                ? AppBar(
                    title: Text(
                      readerState.documentName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      // Table of Contents / Outline Drawer Trigger
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.bookmarks_outlined),
                          tooltip: 'Table of Contents',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),

                      // Grounded AI Assistant Drawer
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                        tooltip: 'AI Document Assistant',
                        onPressed: () => _openAiAssistant(context),
                      ),

                      // In-document Search Toggle
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: readerState.showSearch ? Colors.blueAccent : null,
                        ),
                        tooltip: 'Search (Ctrl+F)',
                        onPressed: () => notifier.toggleSearch(),
                      ),

                      // Thumbnail Strip Toggle
                      IconButton(
                        icon: Icon(
                          Icons.view_carousel_outlined,
                          color: _showThumbnails ? Colors.blueAccent : null,
                        ),
                        tooltip: 'Thumbnails',
                        onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
                      ),

                      // Reading Theme Toggle
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
                          if (isToolActive) {
                            annNotifier.setActiveTool(AnnotationTool.none);
                          } else {
                            annNotifier.setActiveTool(AnnotationTool.pen);
                          }
                        },
                      ),

                      // Save & Burn Annotations to PDF
                      if (annotationState.annotations.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.save_outlined, color: Colors.green),
                          tooltip: 'Burn & Save Annotations (Ctrl+S)',
                          onPressed: () => _handleBurnAndSave(context, annNotifier),
                        ),

                      // More Actions: Forms, Security, Page Organizer
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (val) {
                          if (val == 'organizer') {
                            _openPageOrganizer(context, readerState);
                          } else if (val == 'forms') {
                            _openFormFields(context, pdfService);
                          } else if (val == 'protect') {
                            _openPasswordProtect(context, pdfService, filePicker);
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
                        pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
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

                // Live In-Document Search Overlay Bar
                if (readerState.showSearch)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: ReaderSearchBar(
                      searcher: _searcher,
                      onClose: () => notifier.toggleSearch(),
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

                // Bottom Thumbnail Navigation Strip
                if (_showThumbnails && !isToolActive)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ThumbnailStrip(
                      pageCount: readerState.pageCount,
                      currentPage: readerState.currentPage,
                      onSelectPage: (p) => _goToPage(p),
                    ),
                  ),

                // Bottom Reading Position Indicator Pill
                if (readerState.showControls && !isToolActive && !_showThumbnails)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(20),
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white.withValues(alpha: 0.95),
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
          ),
        ),
      ),
    );
  }

  void _goToPage(int page) {
    if (_pdfController.isReady) {
      _pdfController.goToPage(pageNumber: page);
    }
  }

  Future<void> _handleBurnAndSave(BuildContext context, AnnotationNotifier annNotifier) async {
    final success = await annNotifier.burnAnnotationsToFile(
      widget.params.path,
      widget.params.path,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Annotations successfully burned into PDF stream (ISO 32000)!'
                : 'Failed to burn annotations.',
          ),
        ),
      );
    }
  }

  void _openAiAssistant(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiAssistantSheet(
        pageTexts: _extractedPageTexts,
        onJumpToPage: (p) {
          Navigator.of(ctx).pop();
          _goToPage(p);
        },
      ),
    );
  }

  void _openPageOrganizer(BuildContext context, ReaderState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageOrganizerScreen(
          params: PageOrganizerParams(
            path: state.documentPath,
            id: state.documentId,
            name: state.documentName,
            pageCount: state.pageCount,
          ),
        ),
      ),
    );
  }

  void _openFormFields(BuildContext context, SyncfusionPdfService pdfService) {
    showDialog<bool>(
      context: context,
      builder: (_) => FormFieldsDialog(
        documentPath: widget.params.path,
        pdfService: pdfService,
      ),
    );
  }

  void _openPasswordProtect(
    BuildContext context,
    SyncfusionPdfService pdfService,
    FilePickerService filePicker,
  ) {
    showDialog<String>(
      context: context,
      builder: (_) => PasswordProtectDialog(
        documentPath: widget.params.path,
        pdfService: pdfService,
        filePicker: filePicker,
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
            -1.0, 0, 0, 0, 255,
            0, -1.0, 0, 0, 255,
            0, 0, -1.0, 0, 255,
            0, 0, 0, 1.0, 0,
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

// Intent definitions for keyboard shortcuts
class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _PrevPageIntent extends Intent {
  const _PrevPageIntent();
}

class _NextPageIntent extends Intent {
  const _NextPageIntent();
}
