import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/reader/domain/reader_layout_engine.dart';
import 'package:it_pdf/features/reader/domain/reader_state.dart';
import 'package:pdfrx/pdfrx.dart';

class MockLayoutPage implements PdfPage {
  @override
  final int pageNumber;
  @override
  final double width;
  @override
  final double height;

  MockLayoutPage({
    required this.pageNumber,
    required this.width,
    required this.height,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const standardParams = PdfViewerParams(margin: 12.0);
  const zeroMarginParams = PdfViewerParams(margin: 0.0);

  // Mixed dimensions
  final a4Portrait = MockLayoutPage(pageNumber: 1, width: 595.0, height: 842.0);
  final letterLandscape = MockLayoutPage(
    pageNumber: 2,
    width: 792.0,
    height: 612.0,
  );
  final customSquare = MockLayoutPage(
    pageNumber: 3,
    width: 500.0,
    height: 500.0,
  );
  final tallDoc = MockLayoutPage(pageNumber: 4, width: 420.0, height: 950.0);
  final wideSpread = MockLayoutPage(pageNumber: 5, width: 900.0, height: 600.0);

  group('ReaderLayoutEngine — Pure Dart Layout Geometry & Non-Overlap Invariants', () {
    test('handles empty document across all 4 layouts without throwing', () {
      final layouts = [
        ReaderLayout.continuousVertical,
        ReaderLayout.continuousHorizontal,
        ReaderLayout.singlePage,
        ReaderLayout.twoPage,
      ];

      for (final l in layouts) {
        final result = ReaderLayoutEngine.calculatePageLayout(
          [],
          standardParams,
          l,
        );
        expect(result.pageLayouts, isEmpty);
        expect(result.documentSize, equals(Size.zero));
      }
    });

    test(
      'continuousVertical calculates strict vertical chain with horizontal centering',
      () {
        final pages = [a4Portrait, letterLandscape, customSquare];
        final layout = ReaderLayoutEngine.calculatePageLayout(
          pages,
          standardParams,
          ReaderLayout.continuousVertical,
        );

        const maxW = 792.0;
        final expectedDocWidth = maxW + (standardParams.margin * 2);
        expect(layout.documentSize.width, equals(expectedDocWidth));

        var expectedY = standardParams.margin;
        for (var i = 0; i < pages.length; i++) {
          final p = pages[i];
          final rect = layout.pageLayouts[i];

          expect(rect.width, equals(p.width));
          expect(rect.height, equals(p.height));
          expect(rect.top, equals(expectedY));
          expect(rect.left, closeTo((expectedDocWidth - p.width) / 2, 0.01));

          expectedY += p.height + standardParams.margin;
        }
        expect(layout.documentSize.height, equals(expectedY));
      },
    );

    test(
      'continuousHorizontal calculates strict horizontal chain with vertical centering',
      () {
        final pages = [a4Portrait, letterLandscape, tallDoc];
        final layout = ReaderLayoutEngine.calculatePageLayout(
          pages,
          standardParams,
          ReaderLayout.continuousHorizontal,
        );

        const maxH = 950.0;
        final expectedDocHeight = maxH + (standardParams.margin * 2);
        expect(layout.documentSize.height, equals(expectedDocHeight));

        var expectedX = standardParams.margin;
        for (var i = 0; i < pages.length; i++) {
          final p = pages[i];
          final rect = layout.pageLayouts[i];

          expect(rect.width, equals(p.width));
          expect(rect.height, equals(p.height));
          expect(rect.left, equals(expectedX));
          expect(rect.top, closeTo((expectedDocHeight - p.height) / 2, 0.01));

          expectedX += p.width + standardParams.margin;
        }
        expect(layout.documentSize.width, equals(expectedX));
      },
    );

    test('singlePage guarantees discrete isolated non-overlapping slots', () {
      final pages = [
        a4Portrait,
        letterLandscape,
        customSquare,
        tallDoc,
        wideSpread,
      ];
      final layout = ReaderLayoutEngine.calculatePageLayout(
        pages,
        standardParams,
        ReaderLayout.singlePage,
      );

      const maxW = 900.0;
      const maxH = 950.0;
      final slotW = maxW + standardParams.margin * 2;
      final slotH = maxH + standardParams.margin * 2;

      expect(layout.documentSize.width, equals(pages.length * slotW));
      expect(layout.documentSize.height, equals(slotH));

      for (var i = 0; i < pages.length; i++) {
        final p = pages[i];
        final rect = layout.pageLayouts[i];
        expect(rect.width, equals(p.width));
        expect(rect.height, equals(p.height));

        final slotStart = i * slotW;
        final slotEnd = slotStart + slotW;

        expect(rect.left, greaterThanOrEqualTo(slotStart));
        expect(rect.right, lessThanOrEqualTo(slotEnd));
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(rect.bottom, lessThanOrEqualTo(slotH));

        // Invariant: no overlap with preceding or subsequent slots
        if (i > 0) {
          final prevRect = layout.pageLayouts[i - 1];
          expect(prevRect.right, lessThanOrEqualTo(rect.left));
        }
      }
    });

    test('twoPage handles 1-page document (cover page alone)', () {
      final pages = [a4Portrait];
      final layout = ReaderLayoutEngine.calculatePageLayout(
        pages,
        standardParams,
        ReaderLayout.twoPage,
      );

      final maxW = a4Portrait.width;
      final expectedSpreadWidth = (maxW * 2) + (standardParams.margin * 3);
      expect(layout.documentSize.width, equals(expectedSpreadWidth));

      final cover = layout.pageLayouts[0];
      expect(
        cover.left,
        closeTo((expectedSpreadWidth - a4Portrait.width) / 2, 0.01),
      );
      expect(cover.top, equals(standardParams.margin));
      expect(
        layout.documentSize.height,
        equals(
          standardParams.margin + a4Portrait.height + standardParams.margin,
        ),
      );
    });

    test(
      'twoPage handles 2-page document (cover on row 1, lone page on row 2)',
      () {
        final pages = [a4Portrait, letterLandscape];
        final layout = ReaderLayoutEngine.calculatePageLayout(
          pages,
          standardParams,
          ReaderLayout.twoPage,
        );

        final maxW = math.max(a4Portrait.width, letterLandscape.width);
        final expectedSpreadWidth = (maxW * 2) + (standardParams.margin * 3);

        final cover = layout.pageLayouts[0];
        final p2 = layout.pageLayouts[1];

        // Both cover and lone trailing page are centered
        expect(
          cover.left,
          closeTo((expectedSpreadWidth - a4Portrait.width) / 2, 0.01),
        );
        expect(
          p2.left,
          closeTo((expectedSpreadWidth - letterLandscape.width) / 2, 0.01),
        );

        // Row 2 is positioned below row 1 without overlap
        expect(
          p2.top,
          greaterThanOrEqualTo(cover.bottom + standardParams.margin),
        );
      },
    );

    test(
      'twoPage handles 3-page document (cover on row 1, facing pages 2 & 3 on row 2)',
      () {
        final pages = [a4Portrait, letterLandscape, customSquare];
        final layout = ReaderLayoutEngine.calculatePageLayout(
          pages,
          standardParams,
          ReaderLayout.twoPage,
        );

        const maxW = 792.0;
        final cover = layout.pageLayouts[0];
        final leftPage = layout.pageLayouts[1];
        final rightPage = layout.pageLayouts[2];

        expect(
          leftPage.top,
          greaterThanOrEqualTo(cover.bottom + standardParams.margin),
        );
        expect(
          rightPage.top,
          greaterThanOrEqualTo(cover.bottom + standardParams.margin),
        );

        // Invariant: facing pages must meet at the spine gutter without overlapping
        expect(leftPage.right, equals(standardParams.margin + maxW));
        expect(rightPage.left, equals(standardParams.margin * 2 + maxW));
        expect(rightPage.left - leftPage.right, equals(standardParams.margin));
      },
    );

    test(
      'twoPage handles 4-page and 5-page documents with mixed heights without vertical collision',
      () {
        final pages = [
          a4Portrait,
          letterLandscape,
          customSquare,
          tallDoc,
          wideSpread,
        ];
        final layout = ReaderLayoutEngine.calculatePageLayout(
          pages,
          standardParams,
          ReaderLayout.twoPage,
        );

        expect(layout.pageLayouts.length, equals(5));

        // Cover (Page 1)
        final p1 = layout.pageLayouts[0];
        // Pair 1 (Pages 2 & 3)
        final p2 = layout.pageLayouts[1];
        final p3 = layout.pageLayouts[2];
        // Pair 2 (Pages 4 & 5)
        final p4 = layout.pageLayouts[3];
        final p5 = layout.pageLayouts[4];

        expect(p2.top, greaterThanOrEqualTo(p1.bottom + standardParams.margin));
        expect(p3.top, greaterThanOrEqualTo(p1.bottom + standardParams.margin));

        final row2Bottom = math.max(p2.bottom, p3.bottom);
        expect(
          p4.top,
          greaterThanOrEqualTo(row2Bottom + standardParams.margin),
        );
        expect(
          p5.top,
          greaterThanOrEqualTo(row2Bottom + standardParams.margin),
        );

        // Facing pages must not overlap horizontally
        expect(p3.left, greaterThanOrEqualTo(p2.right));
        expect(p5.left, greaterThanOrEqualTo(p4.right));
      },
    );

    test(
      'zero margin edge case operates cleanly without NaN or zero division',
      () {
        final pages = [a4Portrait, letterLandscape];
        final vertical = ReaderLayoutEngine.calculatePageLayout(
          pages,
          zeroMarginParams,
          ReaderLayout.continuousVertical,
        );
        expect(vertical.pageLayouts[0].top, equals(0.0));
        expect(vertical.pageLayouts[1].top, equals(a4Portrait.height));

        final twoPage = ReaderLayoutEngine.calculatePageLayout(
          pages,
          zeroMarginParams,
          ReaderLayout.twoPage,
        );
        expect(twoPage.pageLayouts[0].top, equals(0.0));
        expect(twoPage.pageLayouts[1].top, equals(a4Portrait.height));
      },
    );
  });
}
