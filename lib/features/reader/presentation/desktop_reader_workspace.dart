import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/providers.dart';
import '../../annotations/domain/annotation_notifier.dart';
import '../../annotations/presentation/annotation_overlay.dart';
import '../../page_organizer/domain/page_organizer_notifier.dart';
import '../../page_organizer/presentation/page_organizer_screen.dart';
import '../../security/presentation/password_protect_dialog.dart';
import '../domain/document_tab.dart';
import '../domain/document_tabs_notifier.dart';
import '../domain/reader_layout_engine.dart';
import '../domain/reader_notifier.dart';
import 'desktop_contextual_panel.dart';
import 'desktop_navigation_panel.dart';
import 'desktop_print_dialog.dart';
import 'desktop_reader_toolbar.dart';
import 'document_properties_dialog.dart';
import 'outline_drawer.dart';
import 'reader_intents.dart';
import 'reader_search_bar.dart';
import 'reader_theme_filter.dart';

/// Complete desktop reading workspace for an active PDF document tab.
class DesktopReaderWorkspace extends ConsumerStatefulWidget {
  final DocumentTab tab;

  const DesktopReaderWorkspace({super.key, required this.tab});

  @override
  ConsumerState<DesktopReaderWorkspace> createState() =>
      _DesktopReaderWorkspaceState();
}

class _DesktopReaderWorkspaceState
    extends ConsumerState<DesktopReaderWorkspace> {
  late final PdfViewerController _pdfController;
  PdfTextSearcher? _searcher;
  List<OutlineItem> _outline = [];
  Map<int, String> _extractedPageTexts = {};
  bool _isLeftPanelOpen = true;
  bool _isRightPanelOpen = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isReady) {
        final targetPage = widget.tab.initialPage.clamp(
          1,
          document.pages.length,
        );
        if (targetPage > 1) {
          controller.goToPage(pageNumber: targetPage);
        } else {
          final matrix = controller.calcMatrixFitWidthForPage(pageNumber: 1);
          if (matrix != null) controller.goTo(matrix);
        }
      }
    });

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
        if (mounted) setState(() => _outline = items);

        if (items.any((item) => !item.isResolved)) {
          unawaited(_lazilyAugmentOutlineWithSyncfusion(document.pages.length));
        }
      } else {
        unawaited(_lazilyAugmentOutlineWithSyncfusion(document.pages.length));
      }
    } catch (_) {}
  }

  Future<void> _lazilyAugmentOutlineWithSyncfusion(int pageCount) async {
    try {
      final pdfService = ref.read(syncfusionPdfServiceProvider);
      final sfBookmarks = await pdfService.extractBookmarks(widget.tab.path);
      if (sfBookmarks.isEmpty || !mounted) return;

      setState(() {
        if (_outline.isEmpty) {
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

  void _goToPage(int page) {
    if (!_pdfController.isReady) return;
    final total = ref
        .read(readerNotifierProvider(widget.tab.readerParams))
        .pageCount;
    final target = page.clamp(1, total);
    _pdfController.goToPage(pageNumber: target);
  }

  Future<bool> _jumpToOutlineDestination(OutlineItem entry) async {
    if (!_pdfController.isReady) return false;
    final pageCount = _pdfController.pageCount;
    bool jumped = false;

    if (entry.dest != null) {
      final destPage = entry.dest!.pageNumber;
      if (destPage >= 1 && destPage <= pageCount) {
        await _pdfController.goToDest(entry.dest);
        jumped = true;
      }
    }

    final targetPage = entry.targetPage;
    if (!jumped &&
        targetPage != null &&
        targetPage >= 1 &&
        targetPage <= pageCount) {
      if (entry.destinationTop != null) {
        final page = _pdfController.document.pages[targetPage - 1];
        final left = entry.destinationLeft != null
            ? entry.destinationLeft!.clamp(0.0, page.width)
            : 0.0;
        final top = entry.destinationTop!.clamp(0.0, page.height);
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
    if (matrix != null) _pdfController.goTo(matrix);
  }

  void _fitPage() {
    if (!_pdfController.isReady) return;
    final pageNumber = _pdfController.pageNumber ?? 1;
    final matrix = _pdfController.calcMatrixForFit(pageNumber: pageNumber);
    if (matrix != null) _pdfController.goTo(matrix);
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

  Future<void> _handleSave() async {
    final annNotifier = ref.read(
      annotationNotifierProvider(widget.tab.id).notifier,
    );
    final success = await annNotifier.burnAnnotationsToFile(
      widget.tab.path,
      widget.tab.path,
    );
    if (mounted) {
      ref
          .read(documentTabsNotifierProvider.notifier)
          .setTabDirtyById(widget.tab.id, false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Document saved with lossless vector annotations (ISO 32000).'
                : 'Failed to save document.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleSaveAs() async {
    final picker = ref.read(filePickerServiceProvider);
    final targetPath = await picker.pickSaveFilePath(
      dialogTitle: 'Save PDF As',
      defaultFileName: 'Copy_${widget.tab.name}',
    );
    if (targetPath != null) {
      final annNotifier = ref.read(
        annotationNotifierProvider(widget.tab.id).notifier,
      );
      final success = await annNotifier.burnAnnotationsToFile(
        widget.tab.path,
        targetPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Saved copy to $targetPath'
                  : 'Failed to save document copy.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePrint() async {
    final readerState = ref.read(
      readerNotifierProvider(widget.tab.readerParams),
    );
    await showDialog<bool>(
      context: context,
      builder: (_) => DesktopPrintDialog(
        documentPath: widget.tab.path,
        documentName: widget.tab.name,
        currentPage: readerState.currentPage,
        pageCount: readerState.pageCount,
      ),
    );
  }

  Future<void> _ensureExtractedText() async {
    if (_extractedPageTexts.isEmpty) {
      try {
        final pdfService = ref.read(syncfusionPdfServiceProvider);
        final texts = await pdfService.extractDocumentText(widget.tab.path);
        if (mounted) setState(() => _extractedPageTexts = texts);
      } catch (_) {}
    }
  }

  void _openPageOrganizer() {
    final state = ref.read(readerNotifierProvider(widget.tab.readerParams));
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

  void _openPasswordProtect() {
    final pdfService = ref.read(syncfusionPdfServiceProvider);
    final filePicker = ref.read(filePickerServiceProvider);
    showDialog<String>(
      context: context,
      builder: (_) => PasswordProtectDialog(
        documentPath: widget.tab.path,
        pdfService: pdfService,
        filePicker: filePicker,
      ),
    );
  }

  void _openProperties() {
    showDialog<void>(
      context: context,
      builder: (_) => DocumentPropertiesDialog(documentPath: widget.tab.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerParams = widget.tab.readerParams;
    final readerState = ref.watch(readerNotifierProvider(readerParams));
    final notifier = ref.read(readerNotifierProvider(readerParams).notifier);
    final annNotifier = ref.read(
      annotationNotifierProvider(widget.tab.id).notifier,
    );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SaveDocumentIntent(),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): const SaveAsDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            const PrintDocumentIntent(),
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
        const SingleActivator(LogicalKeyboardKey.pageUp):
            const PrevPageDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.pageDown):
            const NextPageDocumentIntent(),
        const SingleActivator(LogicalKeyboardKey.home): const FirstPageIntent(),
        const SingleActivator(LogicalKeyboardKey.end): const LastPageIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            const NextTabIntent(),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): const PrevTabIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveDocumentIntent: CallbackAction<SaveDocumentIntent>(
            onInvoke: (_) => _handleSave(),
          ),
          SaveAsDocumentIntent: CallbackAction<SaveAsDocumentIntent>(
            onInvoke: (_) => _handleSaveAs(),
          ),
          PrintDocumentIntent: CallbackAction<PrintDocumentIntent>(
            onInvoke: (_) => _handlePrint(),
          ),
          SearchDocumentIntent: CallbackAction<SearchDocumentIntent>(
            onInvoke: (_) {
              if (_searcher != null) notifier.toggleSearch();
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
            onInvoke: (_) => _fitWidth(),
          ),
          PrevPageDocumentIntent: CallbackAction<PrevPageDocumentIntent>(
            onInvoke: (_) => _goToPage(readerState.currentPage - 1),
          ),
          NextPageDocumentIntent: CallbackAction<NextPageDocumentIntent>(
            onInvoke: (_) => _goToPage(readerState.currentPage + 1),
          ),
          FirstPageIntent: CallbackAction<FirstPageIntent>(
            onInvoke: (_) => _goToPage(1),
          ),
          LastPageIntent: CallbackAction<LastPageIntent>(
            onInvoke: (_) => _goToPage(readerState.pageCount),
          ),
          NextTabIntent: CallbackAction<NextTabIntent>(
            onInvoke: (_) =>
                ref.read(documentTabsNotifierProvider.notifier).nextTab(),
          ),
          PrevTabIntent: CallbackAction<PrevTabIntent>(
            onInvoke: (_) =>
                ref.read(documentTabsNotifierProvider.notifier).previousTab(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              // Dedicated Desktop Toolbar
              DesktopReaderToolbar(
                documentId: widget.tab.id,
                documentPath: widget.tab.path,
                currentPage: readerState.currentPage,
                pageCount: readerState.pageCount,
                currentZoom: _currentZoom,
                currentLayout: readerState.layout,
                currentTheme: readerState.themeMode,
                isLeftPanelOpen: _isLeftPanelOpen,
                isRightPanelOpen: _isRightPanelOpen,
                isSearchOpen: readerState.showSearch,
                isDirty: widget.tab.isDirty,
                onOpen: () async {
                  final picker = ref.read(filePickerServiceProvider);
                  final path = await picker.pickPdfFile();
                  if (path != null) {
                    await ref
                        .read(documentTabsNotifierProvider.notifier)
                        .openFileFromPath(path);
                  }
                },
                onSave: _handleSave,
                onSaveAs: _handleSaveAs,
                onPrint: _handlePrint,
                onPrevPage: () => _goToPage(readerState.currentPage - 1),
                onNextPage: () => _goToPage(readerState.currentPage + 1),
                onJumpToPage: _goToPage,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
                onSetZoom: _setZoom,
                onFitWidth: _fitWidth,
                onFitPage: _fitPage,
                onLayoutChanged: notifier.setLayout,
                onThemeChanged: notifier.setThemeMode,
                onToggleSearch: notifier.toggleSearch,
                onToggleLeftPanel: () =>
                    setState(() => _isLeftPanelOpen = !_isLeftPanelOpen),
                onToggleRightPanel: () async {
                  await _ensureExtractedText();
                  setState(() => _isRightPanelOpen = !_isRightPanelOpen);
                },
                onOpenPageOrganizer: _openPageOrganizer,
                onOpenPasswordProtect: _openPasswordProtect,
                onOpenProperties: _openProperties,
              ),

              // Main Workspace Canvas & Panels Row
              Expanded(
                child: Row(
                  children: [
                    // Docked Left Navigation Panel
                    if (_isLeftPanelOpen)
                      DesktopNavigationPanel(
                        documentPath: widget.tab.path,
                        pageCount: readerState.pageCount,
                        currentPage: readerState.currentPage,
                        outline: _outline,
                        onJumpToPage: _goToPage,
                        onSelectOutline: _jumpToOutlineDestination,
                        onClose: () => setState(() => _isLeftPanelOpen = false),
                      ),

                    // Central PDF Reading Canvas
                    Expanded(
                      child: Stack(
                        children: [
                          applyReaderThemeFilter(
                            themeMode: readerState.themeMode,
                            child: PdfViewer.file(
                              widget.tab.path,
                              controller: _pdfController,
                              params: PdfViewerParams(
                                layoutPages: (pages, prms) =>
                                    ReaderLayoutEngine.calculatePageLayout(
                                      pages,
                                      prms,
                                      readerState.layout,
                                    ),
                                onViewerReady: _onViewerReady,
                                onDocumentChanged: (doc) {
                                  if (doc != null) {
                                    notifier.setPageCount(doc.pages.length);
                                    ref
                                        .read(
                                          documentTabsNotifierProvider.notifier,
                                        )
                                        .updateActiveTabProgress(
                                          readerState.currentPage,
                                          doc.pages.length,
                                        );
                                  }
                                },
                                onPageChanged: (page) {
                                  if (page != null) {
                                    notifier.setPage(page);
                                    ref
                                        .read(
                                          documentTabsNotifierProvider.notifier,
                                        )
                                        .updateActiveTabProgress(
                                          page,
                                          readerState.pageCount,
                                        );
                                  }
                                },
                                pageOverlaysBuilder: (context, pageRect, page) {
                                  return [
                                    AnnotationOverlay(
                                      documentId: widget.tab.id,
                                      pageNumber: page.pageNumber,
                                      pageSize: Size(
                                        pageRect.width,
                                        pageRect.height,
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),

                          // Search Bar Overlay
                          if (readerState.showSearch && _searcher != null)
                            Positioned(
                              top: 12,
                              left: 20,
                              right: 20,
                              child: Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 600,
                                  ),
                                  child: ReaderSearchBar(
                                    searcher: _searcher!,
                                    onClose: notifier.toggleSearch,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Docked Right Contextual Panel (AI & Annotations)
                    if (_isRightPanelOpen)
                      DesktopContextualPanel(
                        documentId: widget.tab.id,
                        documentPath: widget.tab.path,
                        pageTexts: _extractedPageTexts,
                        currentPage: readerState.currentPage,
                        onJumpToPage: _goToPage,
                        onClose: () =>
                            setState(() => _isRightPanelOpen = false),
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
