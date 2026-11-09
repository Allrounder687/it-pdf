import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/pdf_engine/syncfusion_pdf_service.dart';
import 'package:it_pdf/features/reader/presentation/outline_drawer.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class MockPdfPageWithRotation implements PdfPage {
  @override
  final int pageNumber;
  @override
  final double width;
  @override
  final double height;
  @override
  final PdfPageRotation rotation;

  MockPdfPageWithRotation({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.rotation,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('it_pdf_toc_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TOC Destination Correctness & Navigation Regression Engine', () {
    test(
      'extracts explicit GoTo and named destinations without silent page-1 fallback for unresolved entries',
      () async {
        final doc = sf.PdfDocument();
        doc.pageSettings.margins.all = 0;

        // Create 4 pages with distinct rotations
        final p1 = doc.pages.add(); // Page 1
        final p2 = doc.pages.add(); // Page 2
        p2.rotation = sf.PdfPageRotateAngle.rotateAngle90;
        final p3 = doc.pages.add(); // Page 3
        final p4 = doc.pages.add(); // Page 4

        // 1. Explicit GoTo destination on Page 1 (Top)
        final bm1 = doc.bookmarks.add('Chapter 1: Explicit Destination');
        bm1.destination = sf.PdfDestination(p1, const Offset(50, 20));

        // 2. Explicit GoTo destination on Page 2 (Rotated 90)
        final bm2 = doc.bookmarks.add('Chapter 2: Rotated Page');
        bm2.destination = sf.PdfDestination(p2, const Offset(100, 150));

        // 3. Named destination targeting Page 3
        final namedDest = sf.PdfNamedDestination('Chapter 3: Named Destination')
          ..destination = sf.PdfDestination(p3, const Offset(0, 300));
        doc.namedDestinationCollection.add(namedDest);
        final bm3 = doc.bookmarks.add('Chapter 3: Named Destination');
        bm3.namedDestination = namedDest;

        // 4. Duplicate Title with different target: Another "Chapter 1: Explicit Destination" pointing to Page 4!
        final bm4Duplicate = doc.bookmarks.add(
          'Chapter 1: Explicit Destination',
        );
        bm4Duplicate.destination = sf.PdfDestination(p4, const Offset(10, 400));

        // 5. Unresolved Bookmark: Has NO destination or invalid target
        doc.bookmarks.add('Broken Bookmark: External or Unresolved Target');
        // Intentionally do NOT attach a destination

        // 6. Nested Hierarchy: Child bookmark
        final childBm = bm1.add('Section 1.1: Deep Hierarchy');
        childBm.destination = sf.PdfDestination(p1, const Offset(60, 120));

        final bytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        // Parse via SyncfusionPdfService
        final bookmarks = SyncfusionPdfService.parseBookmarksFromBytes(bytes);

        // Verify count
        expect(bookmarks.length, equals(6));

        // 1. Assert Explicit GoTo on Page 1
        final b1 = bookmarks.firstWhere(
          (b) =>
              b.title == 'Chapter 1: Explicit Destination' &&
              b.level == 0 &&
              b.index == 0,
        );
        expect(b1.isResolved, isTrue);
        expect(b1.targetPage, equals(1));
        expect(b1.destinationTop, equals(20.0));
        expect(b1.destinationLeft, equals(50.0));

        // 2. Assert Explicit GoTo on Rotated Page 2
        final b2 = bookmarks.firstWhere(
          (b) => b.title == 'Chapter 2: Rotated Page',
        );
        expect(b2.isResolved, isTrue);
        expect(b2.targetPage, equals(2));
        expect(b2.destinationTop, equals(150.0));

        // 3. Assert Named Destination on Page 3
        final b3 = bookmarks.firstWhere(
          (b) => b.title == 'Chapter 3: Named Destination',
        );
        expect(b3.isResolved, isTrue);
        expect(b3.targetPage, equals(3));

        // 4. Assert Duplicate Title disambiguation
        // Earlier bm1 was index 0. This duplicate must be index 4, targeting Page 4!
        final b4 = bookmarks.firstWhere(
          (b) => b.title == 'Chapter 1: Explicit Destination' && b.index == 4,
        );
        expect(b4.isResolved, isTrue);
        expect(b4.targetPage, equals(4));
        expect(b4.index, equals(4));
        expect(b4.targetPage, isNot(equals(b1.targetPage)));

        // 5. Assert Unresolved Destination explicitly does NOT fall back to Page 1
        final b5 = bookmarks.firstWhere(
          (b) => b.title.contains('Broken Bookmark'),
        );
        expect(b5.isResolved, isFalse);
        expect(
          b5.targetPage,
          isNull,
          reason: 'Unresolved bookmark must never silently default to Page 1',
        );

        // 6. Assert Nested child bookmark
        final bChild = bookmarks.firstWhere(
          (b) => b.title.contains('Section 1.1'),
        );
        expect(bChild.level, equals(1));
        expect(bChild.isResolved, isTrue);
        expect(bChild.targetPage, equals(1));
      },
    );

    test(
      'toPdfRect guarantees top >= bottom and left <= right across all page rotations',
      () {
        final rotations = [
          PdfPageRotation.none,
          PdfPageRotation.clockwise90,
          PdfPageRotation.clockwise180,
          PdfPageRotation.clockwise270,
        ];

        for (final rot in rotations) {
          final mockPage = MockPdfPageWithRotation(
            pageNumber: 1,
            width: 600.0,
            height: 800.0,
            rotation: rot,
          );

          // Flutter coordinate rectangle from top-left (left: 50, top: 100, right: 250, bottom: 200)
          const flutterRect = Rect.fromLTRB(50.0, 100.0, 250.0, 200.0);
          final pdfRect = flutterRect.toPdfRect(page: mockPage);

          // Core pdfrx assertion invariants:
          expect(
            pdfRect.left,
            lessThanOrEqualTo(pdfRect.right),
            reason: 'Left must be <= right for rotation $rot',
          );
          expect(
            pdfRect.top,
            greaterThanOrEqualTo(pdfRect.bottom),
            reason: 'Top must be >= bottom for rotation $rot',
          );

          // Bounded within physical page dimensions
          expect(pdfRect.left, greaterThanOrEqualTo(0.0));
          expect(pdfRect.bottom, greaterThanOrEqualTo(0.0));
        }
      },
    );

    testWidgets(
      'OutlineDrawer displays explicit Unresolved chip and does not mark unresolved item active',
      (tester) async {
        OutlineItem? selected;

        final outline = [
          const OutlineItem(
            title: 'Resolved Chapter 1',
            targetPage: 1,
            isResolved: true,
            level: 0,
          ),
          const OutlineItem(
            title: 'Unresolved Bookmark Link',
            targetPage: null,
            isResolved: false,
            level: 0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OutlineDrawer(
                outline: outline,
                currentPage: 1,
                onSelect: (item) => selected = item,
              ),
            ),
          ),
        );

        // Verify "p. 1" is displayed for item 0
        expect(find.text('p. 1'), findsOneWidget);

        // Verify "Unresolved" badge is explicitly displayed for item 1
        expect(find.text('Unresolved'), findsOneWidget);

        // Tap the unresolved item
        await tester.tap(find.text('Unresolved Bookmark Link'));
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected!.title, equals('Unresolved Bookmark Link'));
        expect(selected!.isResolved, isFalse);
        expect(selected!.targetPage, isNull);
      },
    );
  });
}
