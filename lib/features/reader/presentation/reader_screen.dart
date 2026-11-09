import 'dart:math' as math;
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
import 'reader_app_bar.dart';
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

  static PdfPageLayout calculatePageLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
    ReaderLayout layout,
  ) {
    switch (layout) {
      case ReaderLayout.continuousVertical:
        return _verticalPageLayout(pages, params);
      case ReaderLayout.continuousHorizontal:
        return _horizontalPageLayout(pages, params);
      case ReaderLayout.singlePage:
        return _singlePageLayout(pages, params);
      case ReaderLayout.twoPage:
        return _twoPageSpreadLayout(pages, params);
    }
  }

  static PdfPageLayout _verticalPageLayout(List<PdfPage> pages, PdfViewerParams params) {
    final width = pages.fold(0.0, (w, p) => math.max(w, p.width)) + params.margin * 2;
    final pageLayout = <Rect>[];
    var y = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final rect = Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height);
      pageLayout.add(rect);
      y += page.height + params.margin;
    }
    return PdfPageLayout(pageLayouts: pageLayout, documentSize: Size(width, y));
  }

  static PdfPageLayout _horizontalPageLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (h, p) => math.max(h, p.height)) + params.margin * 2;
    final pageLayout = <Rect>[];
    var x = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final rect = Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height);
      pageLayout.add(rect);
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: pageLayout, documentSize: Size(x, height));
  }

  static PdfPageLayout _singlePageLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }
    final maxWidth = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final maxHeight = pages.fold(0.0, (h, p) => math.max(h, p.height));
    final slotWidth = maxWidth + params.margin * 2;
    final slotHeight = maxHeight + params.margin * 2;
    final pageLayout = <Rect>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final x = i * slotWidth + (slotWidth - page.width) / 2;
      final y = (slotHeight - page.height) / 2;
      pageLayout.add(Rect.fromLTWH(x, y, page.width, page.height));
    }
    return PdfPageLayout(pageLayouts: pageLayout, documentSize: Size(pages.length * slotWidth, slotHeight));
  }

  static PdfPageLayout _twoPageSpreadLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }
    final maxPageWidth = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final spreadWidth = (maxPageWidth * 2) + (params.margin * 3);
    final pageLayout = List<Rect>.filled(pages.length, Rect.zero);

    // Page 1 is the cover page: centered horizontally in the spread width
    var y = params.margin;
    final cover = pages[0];
    pageLayout[0] = Rect.fromLTWH(
      (spreadWidth - cover.width) / 2,
      y,
      cover.width,
      cover.height,
    );
    y += cover.height + params.margin;

    // Remaining pages are paired side-by-side (Facing pages: Page 2 & 3, Page 4 & 5, ...)
    for (var i = 1; i < pages.length; i += 2) {
      final leftPage = pages[i];
      if (i + 1 < pages.length) {
        final rightPage = pages[i + 1];
        final rowHeight = math.max(leftPage.height, rightPage.height);
        final leftX = params.margin + (maxPageWidth - leftPage.width);
        final leftY = y + (rowHeight - leftPage.height) / 2;
        pageLayout[i] = Rect.fromLTWH(leftX, leftY, leftPage.width, leftPage.height);

        final rightX = params.margin * 2 + maxPageWidth;
        final rightY = y + (rowHeight - rightPage.height) / 2;
        pageLayout[i + 1] = Rect.fromLTWH(rightX, rightY, rightPage.width, rightPage.height);

        y += rowHeight + params.margin;
      } else {
        // Trailing lone page: centered
        final leftX = (spreadWidth - leftPage.width) / 2;
        pageLayout[i] = Rect.fromLTWH(leftX, y, leftPage.width, leftPage.height);
        y += leftPage.height + params.margin;
      }
    }

    return PdfPageLayout(pageLayouts: pageLayout, documentSize: Size(spreadWidth, y));
  }
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PdfViewerController _pdfController;
  PdfTextSearcher? _searcher;
  List<OutlineItem> _outline = [];
  Map<int, String> _extractedPageTexts = {};
  bool _showThumbnails = false;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _pdfController.addListener(_onControllerMatrixChanged);
  }

  void _onControllerMatrixChanged() {
    if (mounted && _pdfController.isReady) {
      final zoom = _pdfController.currentZoom;
      if ((zoom - _currentZoom).abs() > 0.01) {
        setState(() => _currentZoom = zoom);
      }
    }
  }

  Future<void> _onViewerReady(PdfDocument document, PdfViewerController controller) async {
    if (!mounted) return;
    setState(() {
      _searcher = PdfTextSearcher(controller);
    });

    // Ensure initial page is actively positioned and rendered without requiring interaction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isReady) {
        final targetPage = widget.params.initialPage.clamp(1, document.pages.length);
        if (targetPage > 1) {
          controller.goToPage(pageNumber: targetPage);
        } else {
          final matrix = controller.calcMatrixFitWidthForPage(pageNumber: 1);
          if (matrix != null) {
            controller.goTo(matrix);
          }
        }
      }
    });

    try {
      final pdfService = ref.read(syncfusionPdfServiceProvider);
      final sfBookmarks = await pdfService.extractBookmarks(widget.params.path);
      final sfMap = {for (final b in sfBookmarks) b.title.trim().toLowerCase(): b};

      final nativeOutline = await document.loadOutline();
      if (nativeOutline.isNotEmpty) {
        final items = <OutlineItem>[];
        void traverse(List<PdfOutlineNode> nodes, int level) {
          for (final n in nodes) {
            final cleanTitle = n.title.trim();
            final sfMatch = sfMap[cleanTitle.toLowerCase()];
            final targetPage = n.dest?.pageNumber ?? sfMatch?.targetPage ?? 1;
            items.add(OutlineItem(
              title: cleanTitle.isNotEmpty ? cleanTitle : 'Section',
              targetPage: targetPage,
              destinationTop: sfMatch?.destinationTop,
              destinationLeft: sfMatch?.destinationLeft,
              dest: n.dest,
              level: level,
            ));
            if (n.children.isNotEmpty) {
              traverse(n.children, level + 1);
            }
          }
        }
        traverse(nativeOutline, 0);
        if (mounted) {
          setState(() => _outline = items);
        }
      } else if (sfBookmarks.isNotEmpty) {
        if (mounted) {
          setState(() {
            _outline = sfBookmarks
                .map((b) => OutlineItem(
                      title: b.title,
                      targetPage: b.targetPage,
                      destinationTop: b.destinationTop,
                      destinationLeft: b.destinationLeft,
                      level: b.level,
                    ))
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pdfController.removeListener(_onControllerMatrixChanged);
    _searcher?.dispose();
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
        const SingleActivator(LogicalKeyboardKey.equal, control: true): const _ZoomInIntent(),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): const _ZoomOutIntent(),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): const _ZoomResetIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const _PrevPageIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const _NextPageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) => _handleBurnAndSave(context, annNotifier)),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              if (_searcher != null) {
                notifier.toggleSearch();
              }
              return null;
            },
          ),
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) => annNotifier.undo()),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) => annNotifier.redo()),
          _ZoomInIntent: CallbackAction<_ZoomInIntent>(onInvoke: (_) => _zoomIn()),
          _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(onInvoke: (_) => _zoomOut()),
          _ZoomResetIntent: CallbackAction<_ZoomResetIntent>(onInvoke: (_) => _setZoom(1.0)),
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
            key: _scaffoldKey,
            drawer: OutlineDrawer(
              outline: _outline,
              currentPage: readerState.currentPage,
              onSelect: (entry) => _navigateToOutlineEntry(entry),
            ),
            appBar: readerState.showControls
                ? ReaderAppBar(
                    documentName: readerState.documentName,
                    currentPage: readerState.currentPage,
                    pageCount: readerState.pageCount,
                    currentZoom: _currentZoom,
                    currentLayout: readerState.layout,
                    themeMode: readerState.themeMode,
                    isToolActive: isToolActive,
                    hasAnnotations: annotationState.annotations.isNotEmpty,
                    isSearchActive: readerState.showSearch,
                    isSearchReady: _searcher != null,
                    showThumbnails: _showThumbnails,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onSelectZoom: _setZoom,
                    onFitWidth: _fitWidth,
                    onFitPage: _fitPage,
                    onSelectLayout: (layout) => notifier.setLayout(layout),
                    onJumpToPage: (page) => _goToPage(page),
                    onOpenOutline: () => _scaffoldKey.currentState?.openDrawer(),
                    onOpenAiAssistant: () => _openAiAssistant(context),
                    onToggleSearch: () => notifier.toggleSearch(),
                    onToggleThumbnails: () => setState(() => _showThumbnails = !_showThumbnails),
                    onCycleTheme: () => _cycleReadingTheme(readerState, notifier),
                    onToggleAnnotations: () {
                      if (isToolActive) {
                        annNotifier.setActiveTool(AnnotationTool.none);
                      } else {
                        annNotifier.setActiveTool(AnnotationTool.pen);
                      }
                    },
                    onSaveAnnotations: () => _handleBurnAndSave(context, annNotifier),
                    onOpenOrganizer: () => _openPageOrganizer(context, readerState),
                    onOpenForms: () => _openFormFields(context, pdfService),
                    onOpenProtect: () => _openPasswordProtect(context, pdfService, filePicker),
                  )
                : null,
            body: Stack(
              children: [
                // Main PDFium Viewport (Native scroll and wheel handling)
                _applyReadingFilter(
                  themeMode: readerState.themeMode,
                  child: PdfViewer.file(
                    readerState.documentPath,
                    controller: _pdfController,
                    initialPageNumber: widget.params.initialPage
                        .clamp(1, widget.params.initialPageCount > 0 ? widget.params.initialPageCount : 1),
                    params: PdfViewerParams(
                      margin: 12.0,
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      scrollByMouseWheel: 0.2,
                      scaleByPointerScale: 1.0,
                      enableKeyboardNavigation: true,
                      scrollByArrowKey: 40.0,
                      sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(),
                      interactionDelegateProvider: const PdfViewerScrollInteractionDelegateProviderPhysics(
                        panFriction: 6.0,
                        zoomFriction: 6.0,
                      ),
                      layoutPages: (pages, p) => ReaderScreen.calculatePageLayout(pages, p, readerState.layout),
                      viewerOverlayBuilder: (context, size, handleLinkTap) => [
                        PdfViewerScrollThumb(
                          controller: _pdfController,
                          orientation: ScrollbarOrientation.right,
                          thumbSize: const Size(20, 48),
                        ),
                      ],
                      pagePaintCallbacks: [
                        if (_searcher != null) _searcher!.pageTextMatchPaintCallback,
                      ],
                      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Loading PDF...',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load PDF document:\n$error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      onViewerReady: _onViewerReady,
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
                      onGeneralTap: (context, controller, details) {
                        if (details.type == PdfViewerGeneralTapType.tap && !isToolActive) {
                          notifier.toggleControls();
                          return true;
                        }
                        return false;
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

                // Live In-Document Search Overlay Bar
                if (readerState.showSearch && _searcher != null)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: ReaderSearchBar(
                      searcher: _searcher!,
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
                      documentPath: readerState.documentPath,
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _goToPage(readerState.currentPage),
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

  Future<void> _navigateToOutlineEntry(OutlineItem entry) async {
    if (!_pdfController.isReady) return;
    bool jumped = false;
    if (entry.dest != null) {
      jumped = await _pdfController.goToDest(entry.dest);
    }
    if (!jumped && entry.targetPage > 0) {
      if (entry.destinationTop != null &&
          entry.targetPage <= _pdfController.document.pages.length) {
        final page = _pdfController.document.pages[entry.targetPage - 1];
        final top = entry.destinationTop!.clamp(0.0, page.height);
        final bottom = math.max(0.0, top - 60.0);
        final left = (entry.destinationLeft ?? 0.0).clamp(0.0, page.width);
        final right = math.min(left + 120.0, page.width);
        await _pdfController.goToRectInsidePage(
          pageNumber: entry.targetPage,
          rect: PdfRect(left, top, right, bottom),
        );
      } else {
        await _pdfController.goToPage(pageNumber: entry.targetPage);
      }
    }
  }

  void _fitWidth() {
    if (!_pdfController.isReady) return;
    final pageNumber = _pdfController.pageNumber ?? 1;
    final matrix = _pdfController.calcMatrixFitWidthForPage(pageNumber: pageNumber);
    if (matrix != null) {
      _pdfController.goTo(matrix);
    }
  }

  void _fitPage() {
    if (!_pdfController.isReady) return;
    final pageNumber = _pdfController.pageNumber ?? 1;
    final matrix = _pdfController.calcMatrixForFit(pageNumber: pageNumber);
    if (matrix != null) {
      _pdfController.goTo(matrix);
    }
  }

  void _zoomIn() {
    if (!_pdfController.isReady) return;
    _pdfController.zoomUp();
  }

  void _zoomOut() {
    if (!_pdfController.isReady) return;
    _pdfController.zoomDown();
  }

  void _setZoom(double zoom) {
    if (!_pdfController.isReady) return;
    _pdfController.setZoom(_pdfController.centerPosition, zoom);
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

  Future<void> _openAiAssistant(BuildContext context) async {
    if (_extractedPageTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extracting document text for AI analysis...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfService = ref.read(syncfusionPdfServiceProvider);
      try {
        final texts = await pdfService.extractDocumentText(widget.params.path);
        if (mounted) {
          setState(() => _extractedPageTexts = texts);
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
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

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}

class _PrevPageIntent extends Intent {
  const _PrevPageIntent();
}

class _NextPageIntent extends Intent {
  const _NextPageIntent();
}
