import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/pdf_engine/syncfusion_pdf_service.dart';
import 'package:it_pdf/core/storage/safe_document_storage.dart';
import 'package:it_pdf/features/annotations/domain/annotation_model.dart';
import 'package:it_pdf/features/annotations/domain/annotation_state.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'fixtures/pdf_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SafeDocumentStorage storage;
  late SyncfusionPdfService pdfService;
  late File fixtureFile;
  final now = DateTime(2026, 11, 9);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('it_pdf_annotations_test_');
    storage = SafeDocumentStorage();
    pdfService = SyncfusionPdfService(safeStorage: storage);
    final fixturePath = p.join(tempDir.path, 'source_annotations.pdf');
    fixtureFile = await PdfTestFixtures.createComplexForensicPdfFixture(targetPath: fixturePath);
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Annotation Correctness & Burning Engine', () {
    test('burnAnnotationsToPdf successfully burns freehand highlighter strokes without silent drop', () async {
      final outputPath = p.join(tempDir.path, 'highlighter_burned.pdf');

      // Freehand highlighter stroke with multiple points (previously dropped silently!)
      final freehandHighlighter = Annotation(
        id: 'ann_highlighter_1',
        documentId: 'doc_1',
        pageNumber: 1,
        type: AnnotationType.highlight,
        colorValue: 0xFFFFEB3B, // Yellow
        strokeWidth: 15.0,
        opacity: 0.4,
        points: const [
          NormalizedPoint(0.1, 0.1),
          NormalizedPoint(0.2, 0.1),
          NormalizedPoint(0.3, 0.1),
          NormalizedPoint(0.4, 0.1),
        ],
        createdAt: now,
      );

      final resultPath = await pdfService.burnAnnotationsToPdf(
        sourcePath: fixtureFile.path,
        outputPath: outputPath,
        annotations: [freehandHighlighter],
      );

      expect(resultPath, equals(outputPath));
      expect(File(outputPath).existsSync(), isTrue);

      // Reopen output PDF and verify file size is greater than original (content stream grew)
      final originalSize = await fixtureFile.length();
      final burnedSize = await File(outputPath).length();
      expect(burnedSize, greaterThan(originalSize));

      final doc = sf.PdfDocument(inputBytes: await File(outputPath).readAsBytes());
      expect(doc.pages.count, equals(3));
      doc.dispose();
    });

    test('burnAnnotationsToPdf burns text markup, shapes, arrows, and sticky notes', () async {
      final outputPath = p.join(tempDir.path, 'multi_annotations_burned.pdf');

      final annotations = [
        // Underline markup
        Annotation(
          id: 'ann_underline',
          documentId: 'doc_1',
          pageNumber: 1,
          type: AnnotationType.underline,
          colorValue: 0xFF2196F3,
          rect: const NormalizedRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.25),
          createdAt: now,
        ),
        // Strikethrough markup
        Annotation(
          id: 'ann_strike',
          documentId: 'doc_1',
          pageNumber: 1,
          type: AnnotationType.strikethrough,
          colorValue: 0xFFF44336,
          rect: const NormalizedRect(left: 0.1, top: 0.3, right: 0.8, bottom: 0.35),
          createdAt: now,
        ),
        // Rectangle vector
        Annotation(
          id: 'ann_rect',
          documentId: 'doc_1',
          pageNumber: 1,
          type: AnnotationType.rectangle,
          colorValue: 0xFF4CAF50,
          strokeWidth: 2.0,
          rect: const NormalizedRect(left: 0.1, top: 0.4, right: 0.5, bottom: 0.5),
          createdAt: now,
        ),
        // Arrow vector
        Annotation(
          id: 'ann_arrow',
          documentId: 'doc_1',
          pageNumber: 1,
          type: AnnotationType.arrow,
          colorValue: 0xFF9C27B0,
          points: const [NormalizedPoint(0.1, 0.6), NormalizedPoint(0.5, 0.6)],
          createdAt: now,
        ),
        // Sticky note popup
        Annotation(
          id: 'ann_note',
          documentId: 'doc_1',
          pageNumber: 1,
          type: AnnotationType.stickyNote,
          colorValue: 0xFFFFC107,
          textContent: 'Critical forensic audit note.',
          rect: const NormalizedRect(left: 0.7, top: 0.7, right: 0.75, bottom: 0.75),
          createdAt: now,
        ),
      ];

      final resultPath = await pdfService.burnAnnotationsToPdf(
        sourcePath: fixtureFile.path,
        outputPath: outputPath,
        annotations: annotations,
      );

      expect(resultPath, equals(outputPath));

      final doc = sf.PdfDocument(inputBytes: await File(outputPath).readAsBytes());
      expect(doc.pages.count, equals(3));
      // Verify annotations exist in page 1 annotations collection
      expect(doc.pages[0].annotations.count, greaterThanOrEqualTo(2));
      doc.dispose();
    });

    test('draftAnnotations filters out committed annotations to eliminate double rendering', () {
      final ann1 = Annotation(
        id: 'ann_1',
        documentId: 'doc_1',
        pageNumber: 1,
        type: AnnotationType.ink,
        colorValue: 0xFF000000,
        isCommitted: false,
        createdAt: now,
      );
      final ann2 = Annotation(
        id: 'ann_2',
        documentId: 'doc_1',
        pageNumber: 1,
        type: AnnotationType.highlight,
        colorValue: 0xFFFFEB3B,
        isCommitted: true, // Already burned into PDF
        createdAt: now,
      );

      final state = AnnotationState(
        annotations: [ann1, ann2],
      );

      // Total annotations includes both
      expect(state.annotations.length, equals(2));

      // draftAnnotations only returns uncommitted ones
      expect(state.draftAnnotations.length, equals(1));
      expect(state.draftAnnotations.first.id, equals('ann_1'));

      // Page filter also strictly excludes committed annotations
      final page1Drafts = state.draftAnnotationsForPage(1);
      expect(page1Drafts.length, equals(1));
      expect(page1Drafts.first.id, equals('ann_1'));
    });
  });
}
