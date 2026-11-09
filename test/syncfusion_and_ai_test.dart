import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/pdf_engine/syncfusion_pdf_service.dart';
import 'package:it_pdf/features/ai_assistant/domain/ai_document_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  group('SyncfusionPdfService & AI Document Assistant Tests', () {
    late Directory tempDir;
    late SyncfusionPdfService pdfService;
    late AiDocumentService aiService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('it_pdf_test_');
      pdfService = SyncfusionPdfService();
      aiService = AiDocumentService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'losslessly merges two PDFs and verifies total page count and text',
      () async {
        // Create doc 1
        final d1 = sf.PdfDocument();
        d1.pages.add().graphics.drawString(
          'First Section Text',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );
        final p1Path = '${tempDir.path}/doc1.pdf';
        await File(p1Path).writeAsBytes(d1.saveSync());
        d1.dispose();

        // Create doc 2
        final d2 = sf.PdfDocument();
        d2.pages.add().graphics.drawString(
          'Second Section Text',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );
        final p2Path = '${tempDir.path}/doc2.pdf';
        await File(p2Path).writeAsBytes(d2.saveSync());
        d2.dispose();

        // Merge
        final mergedPath = '${tempDir.path}/merged.pdf';
        await pdfService.mergePdfs(
          sourcePaths: [p1Path, p2Path],
          outputPath: mergedPath,
        );

        final mergedFile = File(mergedPath);
        expect(await mergedFile.exists(), true);

        // Verify text extraction
        final extracted = await pdfService.extractDocumentText(mergedPath);
        expect(extracted.length, 2);
        expect(extracted[1]!.contains('First Section'), true);
        expect(extracted[2]!.contains('Second Section'), true);
      },
    );

    test(
      'extractPages preserves selected pages and custom rotations',
      () async {
        final doc = sf.PdfDocument();
        doc.pages.add().graphics.drawString(
          'Page 1 Content',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );
        doc.pages.add().graphics.drawString(
          'Page 2 Content',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );
        doc.pages.add().graphics.drawString(
          'Page 3 Content',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );

        final srcPath = '${tempDir.path}/source3.pdf';
        await File(srcPath).writeAsBytes(doc.saveSync());
        doc.dispose();

        final outPath = '${tempDir.path}/extracted_p1_p3.pdf';
        await pdfService.extractPages(
          sourcePath: srcPath,
          pageNumbers: [1, 3],
          pageRotations: {3: 90},
          outputPath: outPath,
        );

        final extracted = await pdfService.extractDocumentText(outPath);
        expect(extracted.length, 2);
        expect(extracted[1]!.contains('Page 1'), true);
        expect(extracted[2]!.contains('Page 3'), true);
      },
    );

    test(
      'protectPdfWithPassword encrypts document and verifies password requirement',
      () async {
        final doc = sf.PdfDocument();
        doc.pages.add().graphics.drawString(
          'Confidential Data',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        );
        final srcPath = '${tempDir.path}/plain.pdf';
        await File(srcPath).writeAsBytes(doc.saveSync());
        doc.dispose();

        final protectedPath = '${tempDir.path}/protected.pdf';
        await pdfService.protectPdfWithPassword(
          sourcePath: srcPath,
          userPassword: 'secretUser123',
          ownerPassword: 'secretOwner123',
          outputPath: protectedPath,
        );

        // Verify cannot open without password
        expect(
          () =>
              sf.PdfDocument(inputBytes: File(protectedPath).readAsBytesSync()),
          throwsA(isA<ArgumentError>()),
        );

        // Verify can open with correct user password
        final unlocked = sf.PdfDocument(
          inputBytes: File(protectedPath).readAsBytesSync(),
          password: 'secretUser123',
        );
        expect(unlocked.pages.count, 1);
        unlocked.dispose();
      },
    );

    test('AiDocumentService grounds summaries, dates and citations', () {
      final mockTexts = {
        1: 'Contract signed on October 15, 2026. The contractor shall deliver all software modules.',
        2: 'Project budget is set. The contractor must submit invoices by December 1, 2026.',
      };

      final summary = aiService.generateSummary(mockTexts);
      expect(summary.contains('[Page 1]'), true);
      expect(summary.contains('[Page 2]'), true);

      final dates = aiService.extractKeyDates(mockTexts);
      expect(dates.contains('October 15, 2026'), true);
      expect(dates.contains('[Page 1]'), true);

      final actions = aiService.extractActionItems(mockTexts);
      expect(actions.contains('shall deliver'), true);
      expect(actions.contains('[Page 1]'), true);

      final answerFound = aiService.answerQuestion(
        question: 'When must invoices be submitted?',
        pageTexts: mockTexts,
      );
      expect(answerFound.contains('[Page 2]'), true);

      final answerNotFound = aiService.answerQuestion(
        question: 'What is the rocket launch schedule?',
        pageTexts: mockTexts,
      );
      expect(answerNotFound.contains('not found in this document'), true);
    });
  });
}
