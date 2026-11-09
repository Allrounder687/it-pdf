import 'dart:math' as math;
import 'dart:ui';
import 'package:pdfrx/pdfrx.dart';
import 'reader_state.dart';

/// Pure Dart layout engine for calculating viewport geometry and page rectangles
/// across all 4 document reading modes.
///
/// Ensures zero page overlap, correct spread alignment, margin clamping,
/// and responsive support for mixed page dimensions (A4, Letter, Landscape, Rotated).
class ReaderLayoutEngine {
  const ReaderLayoutEngine._();

  /// Primary entrypoint dispatching to the active reading layout calculation.
  static PdfPageLayout calculatePageLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
    ReaderLayout layout,
  ) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    switch (layout) {
      case ReaderLayout.continuousVertical:
        return verticalPageLayout(pages, params);
      case ReaderLayout.continuousHorizontal:
        return horizontalPageLayout(pages, params);
      case ReaderLayout.singlePage:
        return singlePageLayout(pages, params);
      case ReaderLayout.twoPage:
        return twoPageSpreadLayout(pages, params);
    }
  }

  /// Continuous vertical layout: scrolls vertically with horizontally centered pages.
  static PdfPageLayout verticalPageLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    final margin = math.max(0.0, params.margin);
    final maxPageWidth = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final docWidth = maxPageWidth + margin * 2;
    final pageLayouts = <Rect>[];
    var currentY = margin;

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final x = (docWidth - page.width) / 2;
      pageLayouts.add(Rect.fromLTWH(x, currentY, page.width, page.height));
      currentY += page.height + margin;
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(docWidth, currentY),
    );
  }

  /// Continuous horizontal layout: scrolls horizontally with vertically centered pages.
  static PdfPageLayout horizontalPageLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    final margin = math.max(0.0, params.margin);
    final maxPageHeight = pages.fold(0.0, (h, p) => math.max(h, p.height));
    final docHeight = maxPageHeight + margin * 2;
    final pageLayouts = <Rect>[];
    var currentX = margin;

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final y = (docHeight - page.height) / 2;
      pageLayouts.add(Rect.fromLTWH(currentX, y, page.width, page.height));
      currentX += page.width + margin;
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(currentX, docHeight),
    );
  }

  /// Single page layout: arranges pages in discrete isolated viewport slots.
  /// Each slot reserves space for the largest page, centering smaller or rotated pages
  /// without overlapping adjacent page boundaries.
  static PdfPageLayout singlePageLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    final margin = math.max(0.0, params.margin);
    final maxWidth = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final maxHeight = pages.fold(0.0, (h, p) => math.max(h, p.height));
    final slotWidth = maxWidth + margin * 2;
    final slotHeight = maxHeight + margin * 2;
    final pageLayouts = <Rect>[];

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final slotOriginX = i * slotWidth;
      final x = slotOriginX + (slotWidth - page.width) / 2;
      final y = (slotHeight - page.height) / 2;
      pageLayouts.add(Rect.fromLTWH(x, y, page.width, page.height));
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(pages.length * slotWidth, slotHeight),
    );
  }

  /// Two-page book spread layout:
  /// - Page 1 is the cover page, centered alone in the spread width on row 1.
  /// - Subsequent pages are paired as facing pages: left page right-aligned to spine,
  ///   right page left-aligned to spine.
  /// - Trailing lone odd page (e.g. Page 4 in a 4-page book) is centered alone.
  /// - Row height accommodates the taller page of each facing pair without vertical overlap.
  static PdfPageLayout twoPageSpreadLayout(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    final margin = math.max(0.0, params.margin);
    final maxPageWidth = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final spreadWidth = (maxPageWidth * 2) + (margin * 3);
    final pageLayouts = List<Rect>.filled(pages.length, Rect.zero);

    var currentY = margin;

    // Page 1 is the cover page (centered alone on row 1)
    final cover = pages[0];
    pageLayouts[0] = Rect.fromLTWH(
      (spreadWidth - cover.width) / 2,
      currentY,
      cover.width,
      cover.height,
    );
    currentY += cover.height + margin;

    // Subsequent facing pairs
    for (var i = 1; i < pages.length; i += 2) {
      final leftPage = pages[i];
      if (i + 1 < pages.length) {
        final rightPage = pages[i + 1];
        final rowHeight = math.max(leftPage.height, rightPage.height);

        // Left page spine alignment: right edge touches spine gutter
        final leftX = margin + (maxPageWidth - leftPage.width);
        final leftY = currentY + (rowHeight - leftPage.height) / 2;
        pageLayouts[i] = Rect.fromLTWH(leftX, leftY, leftPage.width, leftPage.height);

        // Right page spine alignment: left edge touches spine gutter
        final rightX = margin * 2 + maxPageWidth;
        final rightY = currentY + (rowHeight - rightPage.height) / 2;
        pageLayouts[i + 1] = Rect.fromLTWH(rightX, rightY, rightPage.width, rightPage.height);

        currentY += rowHeight + margin;
      } else {
        // Lone trailing page: centered alone on its row
        final trailingX = (spreadWidth - leftPage.width) / 2;
        pageLayouts[i] = Rect.fromLTWH(trailingX, currentY, leftPage.width, leftPage.height);
        currentY += leftPage.height + margin;
      }
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(spreadWidth, currentY),
    );
  }
}
