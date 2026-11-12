import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/pdf_engine/advanced_pdf_operations.dart';
import 'package:it_pdf/core/pdf_engine/syncfusion_pdf_service.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Directory tempDir;
  late SyncfusionPdfService pdfService;
  late String samplePdfA;
  late String samplePdfB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('it_pdf_adv_tools_');
    pdfService = SyncfusionPdfService();

    samplePdfA = p.join(tempDir.path, 'sample_a.pdf');
    samplePdfB = p.join(tempDir.path, 'sample_b.pdf');

    await pdfService.createTemplatedDocument(
      title: 'Doc A',
      outputPath: samplePdfA,
      template: BlankPaperTemplate.lined,
      pageCount: 5,
    );
    await pdfService.createTemplatedDocument(
      title: 'Doc B',
      outputPath: samplePdfB,
      template: BlankPaperTemplate.grid,
      pageCount: 3,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('inspectPdf reads accurate page count and byte size', () async {
    final summaryA = await pdfService.inspectPdf(samplePdfA);
    expect(summaryA.pageCount, 5);
    expect(summaryA.fileSizeBytes, greaterThan(0));
    expect(summaryA.isEncrypted, isFalse);
  });

  test(
    'mergePdfsAdvanced merges custom page subsets and generates TOC bookmarks',
    () async {
      final outPath = p.join(tempDir.path, 'merged_adv.pdf');
      await pdfService.mergePdfsAdvanced(
        sources: [
          PdfMergeSource(
            path: samplePdfA,
            pageNumbers: [1, 3, 5],
            bookmarkTitle: 'Chapter Alpha',
          ),
          PdfMergeSource(
            path: samplePdfB,
            pageNumbers: [2],
            bookmarkTitle: 'Chapter Beta',
          ),
        ],
        outputPath: outPath,
        addBookmarks: true,
      );

      final summary = await pdfService.inspectPdf(outPath);
      expect(summary.pageCount, 4);

      final bookmarks = await pdfService.extractBookmarks(outPath);
      expect(bookmarks.length, 2);
      expect(bookmarks[0].title, 'Chapter Alpha');
      expect(bookmarks[0].targetPage, 1);
      expect(bookmarks[1].title, 'Chapter Beta');
      expect(bookmarks[1].targetPage, 4);
    },
  );

  test(
    'splitPdfIntoChunks splits 5-page PDF into 2-page chunks cleanly',
    () async {
      final chunkDir = Directory(p.join(tempDir.path, 'chunks'));
      await chunkDir.create();

      final created = await pdfService.splitPdfIntoChunks(
        sourcePath: samplePdfA,
        outputDirectory: chunkDir.path,
        pagesPerChunk: 2,
      );

      expect(created.length, 3);
      expect((await pdfService.inspectPdf(created[0])).pageCount, 2);
      expect((await pdfService.inspectPdf(created[1])).pageCount, 2);
      expect((await pdfService.inspectPdf(created[2])).pageCount, 1);
    },
  );

  test('compressPdf lossless optimizes valid readable PDF', () async {
    final outPath = p.join(tempDir.path, 'compressed.pdf');
    final res = await pdfService.compressPdf(
      sourcePath: samplePdfA,
      outputPath: outPath,
      mode: PdfCompressionMode.lossless,
    );

    expect(File(res.outputPath).existsSync(), isTrue);
    expect(res.compressedBytes, greaterThan(0));
    final summary = await pdfService.inspectPdf(outPath);
    expect(summary.pageCount, 5);
  });

  test(
    'addWatermark and addPageNumbers stamp valid PDFs without losing pages',
    () async {
      final watermarked = p.join(tempDir.path, 'watermarked.pdf');
      await pdfService.addWatermark(
        sourcePath: samplePdfA,
        outputPath: watermarked,
        text: 'CONFIDENTIAL',
        opacity: 0.3,
        angleDegrees: -45,
        color: const Color(0xFFDC2626),
        pageNumbers: [1, 2],
      );
      expect((await pdfService.inspectPdf(watermarked)).pageCount, 5);

      final numbered = p.join(tempDir.path, 'numbered.pdf');
      await pdfService.addPageNumbers(
        sourcePath: watermarked,
        outputPath: numbered,
        position: PageNumberPosition.bottomRight,
        format: 'EX-{bates}',
        startNumber: 1,
        skipFirstPage: true,
      );
      expect((await pdfService.inspectPdf(numbered)).pageCount, 5);

      final texts = await pdfService.extractDocumentText(numbered);
      expect(texts[1] ?? '', contains('CONFIDENTIAL'));
      expect(texts[1] ?? '', isNot(contains('EX-'))); // Skipped cover page
      expect(texts[2] ?? '', contains('EX-0001'));
      expect(texts[3] ?? '', contains('EX-0002'));
    },
  );

  test(
    'protectPdfWithOptions encrypts and unlockPdf restores readable unencrypted PDF',
    () async {
      final lockedPath = p.join(tempDir.path, 'locked.pdf');
      await pdfService.protectPdfWithOptions(
        sourcePath: samplePdfB,
        outputPath: lockedPath,
        userPassword: 'SecretPassword123!',
        tier: PdfEncryptionTier.aes256,
        allowPrint: true,
        allowCopy: false,
      );

      final lockedSummary = await pdfService.inspectPdf(lockedPath);
      expect(lockedSummary.isEncrypted, isTrue);

      final unlockedPath = p.join(tempDir.path, 'unlocked.pdf');
      await pdfService.unlockPdf(
        sourcePath: lockedPath,
        currentPassword: 'SecretPassword123!',
        outputPath: unlockedPath,
      );

      final unlockedSummary = await pdfService.inspectPdf(unlockedPath);
      expect(unlockedSummary.isEncrypted, isFalse);
      expect(unlockedSummary.pageCount, 3);
    },
  );

  test(
    'mergePdfsAdvanced preserves full landscape dimensions without right-edge cropping',
    () async {
      final landscapePath = p.join(tempDir.path, 'landscape_cert.pdf');
      final landscapeDoc = PdfDocument();
      landscapeDoc.pageSettings.margins.all = 0;
      landscapeDoc.pageSettings.orientation = PdfPageOrientation.landscape;
      landscapeDoc.pageSettings.size = PdfPageSize.a4;
      landscapeDoc.pages.add().graphics.drawString(
        'Landscape Certificate',
        PdfStandardFont(PdfFontFamily.helvetica, 24),
        bounds: const Rect.fromLTWH(40, 40, 600, 40),
      );
      await File(landscapePath).writeAsBytes(await landscapeDoc.save());
      landscapeDoc.dispose();

      final mergedOut = p.join(tempDir.path, 'merged_mixed_orientations.pdf');
      await pdfService.mergePdfsAdvanced(
        sources: [
          PdfMergeSource(path: landscapePath),
          PdfMergeSource(path: samplePdfB, pageNumbers: [1]),
        ],
        outputPath: mergedOut,
      );

      final outBytes = await File(mergedOut).readAsBytes();
      final verifyDoc = PdfDocument(inputBytes: outBytes);
      try {
        expect(verifyDoc.pages.count, 2);
        final page0Size = verifyDoc.pages[0].size;
        final page1Size = verifyDoc.pages[1].size;
        expect(page0Size.width, greaterThan(page0Size.height));
        expect(page0Size.width, greaterThan(800));
        expect(page1Size.height, greaterThan(page1Size.width));
      } finally {
        verifyDoc.dispose();
      }
    },
  );

  test(
    'addWatermark supports direct fractional positioning and full-page tiling',
    () async {
      final tiledPath = p.join(tempDir.path, 'tiled_watermark.pdf');
      await pdfService.addWatermark(
        sourcePath: samplePdfB,
        outputPath: tiledPath,
        text: 'APPROVED',
        fontSize: 32,
        opacity: 0.35,
        angleDegrees: -30,
        color: Colors.green,
        xFraction: 0.72,
        yFraction: 0.25,
        tiled: true,
      );

      final texts = await pdfService.extractDocumentText(tiledPath);
      expect(texts.length, 3);
      for (final pageText in texts.values) {
        expect(pageText, contains('APPROVED'));
      }
    },
  );
}
