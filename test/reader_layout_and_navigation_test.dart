import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/features/reader/domain/reader_state.dart';
import 'package:it_pdf/features/reader/presentation/reader_screen.dart';
import 'package:pdfrx/pdfrx.dart';

/// Test mock for PdfPage to verify layout geometry across all 4 reading modes.
class TestPdfPage implements PdfPage {
  @override
  final int pageNumber;
  @override
  final double width;
  @override
  final double height;

  TestPdfPage({
    required this.pageNumber,
    required this.width,
    required this.height,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const params = PdfViewerParams(margin: 10.0);

  // Mixed page dimensions:
  // Page 1: A4 Portrait (595.0 x 842.0)
  // Page 2: Letter Landscape (792.0 x 612.0)
  // Page 3: Square Custom (500.0 x 500.0)
  // Page 4: Tall Document (400.0 x 900.0)
  final pages = [
    TestPdfPage(pageNumber: 1, width: 595.0, height: 842.0),
    TestPdfPage(pageNumber: 2, width: 792.0, height: 612.0),
    TestPdfPage(pageNumber: 3, width: 500.0, height: 500.0),
    TestPdfPage(pageNumber: 4, width: 400.0, height: 900.0),
  ];

  group('ReaderScreen — Multi-Mode Page Layout & Viewport Geometry', () {
    test('continuousVertical centers mixed page dimensions vertically in sequence', () {
      final layout = ReaderScreen.calculatePageLayout(
        pages,
        params,
        ReaderLayout.continuousVertical,
      );

      // Max width is Page 2 (792.0) + margin * 2 = 812.0
      expect(layout.documentSize.width, equals(812.0));

      // Each page must be centered horizontally
      final p1 = layout.pageLayouts[0];
      expect(p1.left, closeTo((812.0 - 595.0) / 2, 0.01));
      expect(p1.top, equals(10.0));
      expect(p1.width, equals(595.0));
      expect(p1.height, equals(842.0));

      final p2 = layout.pageLayouts[1];
      expect(p2.left, closeTo((812.0 - 792.0) / 2, 0.01));
      expect(p2.top, equals(10.0 + 842.0 + 10.0));
    });

    test('continuousHorizontal centers mixed page dimensions horizontally in sequence', () {
      final layout = ReaderScreen.calculatePageLayout(
        pages,
        params,
        ReaderLayout.continuousHorizontal,
      );

      // Max height is Page 4 (900.0) + margin * 2 = 920.0
      expect(layout.documentSize.height, equals(920.0));

      // Each page must be centered vertically
      final p1 = layout.pageLayouts[0];
      expect(p1.left, equals(10.0));
      expect(p1.top, closeTo((920.0 - 842.0) / 2, 0.01));

      final p2 = layout.pageLayouts[1];
      expect(p2.left, equals(10.0 + 595.0 + 10.0));
      expect(p2.top, closeTo((920.0 - 612.0) / 2, 0.01));
    });

    test('singlePage creates discrete isolated slots for each page', () {
      final layout = ReaderScreen.calculatePageLayout(
        pages,
        params,
        ReaderLayout.singlePage,
      );

      const maxWidth = 792.0;
      final slotWidth = maxWidth + params.margin * 2; // 812.0

      expect(layout.documentSize.width, equals(4 * slotWidth));

      for (var i = 0; i < pages.length; i++) {
        final rect = layout.pageLayouts[i];
        final expectedSlotStart = i * slotWidth;
        expect(rect.left, greaterThanOrEqualTo(expectedSlotStart));
        expect(rect.right, lessThanOrEqualTo(expectedSlotStart + slotWidth));
        expect(rect.width, equals(pages[i].width));
        expect(rect.height, equals(pages[i].height));
      }
    });

    test('twoPage implements book spread with cover page centered on row 1 and facing pages paired', () {
      final layout = ReaderScreen.calculatePageLayout(
        pages,
        params,
        ReaderLayout.twoPage,
      );

      const maxPageWidth = 792.0;
      final spreadWidth = (maxPageWidth * 2) + (params.margin * 3); // 1584 + 30 = 1614

      expect(layout.documentSize.width, equals(spreadWidth));

      // Page 1 (Cover): centered alone on first row
      final cover = layout.pageLayouts[0];
      expect(cover.left, closeTo((spreadWidth - 595.0) / 2, 0.01));
      expect(cover.top, equals(10.0));

      // Page 2 & 3: facing pages paired horizontally on row 2
      final p2 = layout.pageLayouts[1]; // Left facing page
      final p3 = layout.pageLayouts[2]; // Right facing page

      // Left page aligned to spine on left side of gutter
      expect(p2.right, equals(params.margin + maxPageWidth));
      // Right page starts after gutter
      expect(p3.left, equals(params.margin * 2 + maxPageWidth));

      // Vertically centered within row height (row height is max(612, 500) = 612)
      const row2Y = 10.0 + 842.0 + 10.0;
      expect(p2.top, closeTo(row2Y, 0.01));
      expect(p3.top, closeTo(row2Y + (612.0 - 500.0) / 2, 0.01));

      // Page 4 (trailing odd page): centered alone on row 3
      final p4 = layout.pageLayouts[3];
      expect(p4.left, closeTo((spreadWidth - 400.0) / 2, 0.01));
    });
  });
}
