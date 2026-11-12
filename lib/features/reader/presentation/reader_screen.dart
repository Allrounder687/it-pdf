import 'dart:async';
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
import '../domain/reader_layout_engine.dart';
import '../domain/reader_notifier.dart';
import '../domain/reader_state.dart';
import 'outline_drawer.dart';
import 'reader_app_bar.dart';
import 'reader_intents.dart';
import 'reader_search_bar.dart';
import 'reader_theme_filter.dart';
import 'thumbnail_strip.dart';
import 'desktop_pdf_scrollbar.dart';

/// Master PDF Reader Viewport screen powered by PDFium (pdfrx) and Syncfusion PDF Engine.
class ReaderScreen extends ConsumerStatefulWidget {
  final ReaderNotifierParams params;

  const ReaderScreen({super.key, required this.params});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();

  static PdfPageLayout calculatePageLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
    ReaderLayout layout,
  ) => ReaderLayoutEngine.calculatePageLayout(pages, params, layout);
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

  Future<void> _onViewerReady(
    PdfDocument document,
    PdfViewerController controller,
  ) async {
    if (!mounted) return;
    setState(() {
      _searcher = PdfTextSearcher(controller);
    });

    // Ensure initial page is actively positioned and rendered without requiring interaction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isReady) {
        final targetPage = widget.params.initialPage.clamp(
          1,
          document.pages.length,
        );
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

    // Load native PDFium outline first (instantaneous from memory, zero disk or isolate stall)
    try {
      final nativeOutline = await document.loadOutline();
      if (nativeOutline.isNotEmpty) {
        final items = <OutlineItem>[];
        int globalIdx = 0;
        void traverse(
          List<PdfOutlineNode> nodes,
          int level,
          List<int> parentPath,
        ) {
          for (int i = 0; i < nodes.length; i++) {
            final n = nodes[i];
            final currentPath = [...parentPath, i];
            final cleanTitle = n.title.trim();
            final isValid =
                n.dest != null &&
                n.dest!.pageNumber >= 1 &&
                n.dest!.pageNumber <= document.pages.length;
            items.add(
              OutlineItem(
                title: cleanTitle.isNotEmpty
                    ? cleanTitle
                    : 'Section ${globalIdx + 1}',
                targetPage: isValid ? n.dest!.pageNumber : null,
                isResolved: isValid,
                dest: n.dest,
                level: level,
                index: globalIdx++,
                treePath: currentPath,
              ),
            );
            if (n.children.isNotEmpty) {
              traverse(n.children, level + 1, currentPath);
            }
          }
        }

        traverse(nativeOutline, 0, []);
        if (mounted) {
          setState(() => _outline = items);
        }

        // If any destination could not be resolved by PDFium, resolve lazily in background
        if (items.any((item) => !item.isResolved)) {
          unawaited(_lazilyAugmentOutlineWithSyncfusion(document.pages.length));
        }
      } else {
        // Native outline was empty; lazily check Syncfusion in background isolate
        unawaited(_lazilyAugmentOutlineWithSyncfusion(document.pages.length));
      }
    } catch (_) {}
  }

  /// Lazily augments outline entries in the background using Syncfusion's named destination resolution.
  Future<void> _lazilyAugmentOutlineWithSyncfusion(int pageCount) async {
    try {
      final pdfService = ref.read(syncfusionPdfServiceProvider);
      final sfBookmarks = await pdfService.extractBookmarks(widget.params.path);
      if (sfBookmarks.isEmpty || !mounted) return;

      setState(() {
        if (_outline.isEmpty) {
          // Native outline was completely absent, adopt Syncfusion outline directly
          _outline = sfBookmarks
              .map(
                (b) => OutlineItem(
                  title: b.title,
                  targetPage: b.isResolved ? b.targetPage : null,
                  isResolved: b.isResolved,
                  level: b.level,
                  index: b.index,
                  treePath: b.treePath,
                  destinationTop: b.destinationTop,
                  destinationLeft: b.destinationLeft,
                ),
              )
              .toList();
        } else {
          // Merge by pre-order traversal index to preserve order and avoid duplicate title collisions
          final updated = <OutlineItem>[];
          for (final item in _outline) {
            if (item.isResolved && item.targetPage != null) {
              updated.add(item);
            } else if (item.index < sfBookmarks.length) {
              final sfMatch = sfBookmarks[item.index];
              final isMatchResolved =
                  sfMatch.isResolved &&
                  sfMatch.targetPage != null &&
                  sfMatch.targetPage! >= 1 &&
                  sfMatch.targetPage! <= pageCount;
              updated.add(
                OutlineItem(
                  title: item.title,
                  targetPage: isMatchResolved ? sfMatch.targetPage : null,
                  isResolved: isMatchResolved,
                  dest: item.dest,
                  level: item.level,
                  index: item.index,
                  treePath: item.treePath,
                  destinationTop: sfMatch.destinationTop,
                  destinationLeft: sfMatch.destinationLeft,
                ),
              );
            } else {
              updated.add(item);
            }
          }
          _outline = updated;
        }
      });
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
    final annotationState = ref.watch(
      annotationNotifierProvider(widget.params.id),
    );
    final annNotifier = ref.read(
      annotationNotifierProvider(widget.params.id).notifier,
    );
    final pdfService = ref.watch(syncfusionPdfServiceProvider);
    final filePicker = ref.watch(filePickerServiceProvider);

    final isToolActive = annotationState.activeTool != AnnotationTool.none;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SaveDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const SearchDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const UndoActionIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            const RedoActionIntent(),
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            const ZoomInDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            const ZoomOutDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            const ZoomResetDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const PrevPageDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const NextPageDocumentIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveDocumentIntent: CallbackAction<SaveDocumentIntent>(
            onInvoke: (_) => _handleBurnAndSave(context, annNotifier),
          ),
          SearchDocumentIntent: CallbackAction<SearchDocumentIntent>(
            onInvoke: (_) {
              if (_searcher != null) {
                notifier.toggleSearch();
              }
              return null;
            },
          ),
          UndoActionIntent: CallbackAction<UndoActionIntent>(
            onInvoke: (_) => annNotifier.undo(),
          ),
          RedoActionIntent: CallbackAction<RedoActionIntent>(
            onInvoke: (_) => annNotifier.redo(),
          ),
          ZoomInDocumentIntent: CallbackAction<ZoomInDocumentIntent>(
            onInvoke: (_) => _zoomIn(),
          ),
          ZoomOutDocumentIntent: CallbackAction<ZoomOutDocumentIntent>(
            onInvoke: (_) => _zoomOut(),
          ),
          ZoomResetDocumentIntent: CallbackAction<ZoomResetDocumentIntent>(
            onInvoke: (_) => _setZoom(1.0),
          ),
          PrevPageDocumentIntent: CallbackAction<PrevPageDocumentIntent>(
            onInvoke: (_) => _goToPage(
              (readerState.currentPage - 1).clamp(1, readerState.pageCount),
            ),
          ),
          NextPageDocumentIntent: CallbackAction<NextPageDocumentIntent>(
            onInvoke: (_) => _goToPage(
              (readerState.currentPage + 1).clamp(1, readerState.pageCount),
            ),
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
                    onOpenOutline: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                    onOpenAiAssistant: () => _openAiAssistant(context),
                    onToggleSearch: () => notifier.toggleSearch(),
                    onToggleThumbnails: () =>
                        setState(() => _showThumbnails = !_showThumbnails),
                    onCycleTheme: () =>
                        _cycleReadingTheme(readerState, notifier),
                    onToggleAnnotations: () {
                      if (isToolActive) {
                        annNotifier.setActiveTool(AnnotationTool.none);
                      } else {
                        annNotifier.setActiveTool(AnnotationTool.pen);
                      }
                    },
                    onSaveAnnotations: () =>
                        _handleBurnAndSave(context, annNotifier),
                    onOpenOrganizer: () =>
                        _openPageOrganizer(context, readerState),
                    onOpenForms: () => _openFormFields(context, pdfService),
                    onOpenProtect: () =>
                        _openPasswordProtect(context, pdfService, filePicker),
                  )
                : null,
            body: Stack(
              children: [
                // Main PDFium Viewport (Native scroll and wheel handling)
                applyReaderThemeFilter(
                  themeMode: readerState.themeMode,
                  child: PdfViewer.file(
                    readerState.documentPath,
                    controller: _pdfController,
                    initialPageNumber: widget.params.initialPage.clamp(
                      1,
                      widget.params.initialPageCount > 0
                          ? widget.params.initialPageCount
                          : 1,
                    ),
                    params: PdfViewerParams(
                      margin: 12.0,
                      backgroundColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      scrollByMouseWheel: 1.0,
                      scaleByPointerScale: 1.0,
                      enableKeyboardNavigation: true,
                      scrollByArrowKey: 50.0,
                      sizeDelegateProvider:
                          const PdfViewerSizeDelegateProviderLegacy(),
                      interactionDelegateProvider:
                          const PdfViewerScrollInteractionDelegateProviderPhysics(
                            panFriction: 11.0,
                            zoomFriction: 11.0,
                          ),
                      layoutPages: (pages, p) =>
                          ReaderScreen.calculatePageLayout(
                            pages,
                            p,
                            readerState.layout,
                          ),
                      viewerOverlayBuilder: (context, size, handleLinkTap) => [
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 2,
                          child: DesktopPdfScrollbar(
                            controller: _pdfController,
                            orientation: Axis.vertical,
                            pageCount: readerState.pageCount,
                            currentPage: readerState.currentPage,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 16,
                          bottom: 2,
                          child: DesktopPdfScrollbar(
                            controller: _pdfController,
                            orientation: Axis.horizontal,
                            pageCount: readerState.pageCount,
                            currentPage: readerState.currentPage,
                          ),
                        ),
                      ],
                      pagePaintCallbacks: [
                        if (_searcher != null)
                          _searcher!.pageTextMatchPaintCallback,
                      ],
                      loadingBannerBuilder:
                          (context, bytesDownloaded, totalBytes) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(
                                  'Loading PDF...',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      errorBannerBuilder:
                          (context, error, stackTrace, documentRef) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Failed to load PDF document:\n$error',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
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
                        if (details.type == PdfViewerGeneralTapType.tap &&
                            !isToolActive) {
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
                if (readerState.showControls &&
                    !isToolActive &&
                    !_showThumbnails)
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Page ${readerState.currentPage} of ${readerState.pageCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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

  Future<bool> _navigateToOutlineEntry(OutlineItem entry) async {
    if (!_pdfController.isReady) return false;

    if (!entry.isResolved || entry.targetPage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot navigate: "${entry.title}" destination is unresolved or missing.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final targetPage = entry.targetPage!;
    final totalPages = _pdfController.document.pages.length;
    if (targetPage < 1 || targetPage > totalPages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot navigate: Destination page $targetPage exceeds document length ($totalPages pages).',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    bool jumped = false;
    if (entry.dest != null) {
      jumped = await _pdfController.goToDest(entry.dest);
    }

    if (!jumped) {
      final page = _pdfController.document.pages[targetPage - 1];
      if (entry.destinationTop != null) {
        // destinationTop and destinationLeft are measured in points from top-left
        final top = (entry.destinationTop ?? 0.0).clamp(0.0, page.height);
        final left = (entry.destinationLeft ?? 0.0).clamp(0.0, page.width);
        final bottom = math.min(top + 80.0, page.height);
        final right = math.min(left + 120.0, page.width);

        final flutterRect = Rect.fromLTRB(
          math.min(left, right),
          math.min(top, bottom),
          math.max(left, right),
          math.max(top, bottom),
        );
        final pdfRect = flutterRect.toPdfRect(page: page);

        await _pdfController.goToRectInsidePage(
          pageNumber: targetPage,
          rect: pdfRect,
        );
        jumped = true;
      } else {
        await _pdfController.goToPage(pageNumber: targetPage);
        jumped = true;
      }
    }

    return jumped;
  }

  void _fitWidth() {
    if (!_pdfController.isReady) return;
    final pageNumber = _pdfController.pageNumber ?? 1;
    final matrix = _pdfController.calcMatrixFitWidthForPage(
      pageNumber: pageNumber,
    );
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

  Future<void> _handleBurnAndSave(
    BuildContext context,
    AnnotationNotifier annNotifier,
  ) async {
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
}
