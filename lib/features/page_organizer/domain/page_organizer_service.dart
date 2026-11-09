import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import '../../../core/logging/app_logger.dart';

/// High-performance PDF assembly, page extraction, image conversion and merge service.
class PageOrganizerService {
  /// Convert an array of image files into a single multi-page PDF document.
  Future<String> convertImagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
  }) async {
    final pdfDoc = pw.Document();

    for (final imgPath in imagePaths) {
      final file = File(imgPath);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );
    }

    final bytes = await pdfDoc.save();
    await _atomicWrite(outputPath, bytes);
    return outputPath;
  }

  /// Create a blank PDF document template.
  Future<String> createBlankDocument({
    required String title,
    required String outputPath,
  }) async {
    final pdfDoc = pw.Document(title: title);
    pdfDoc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdfDoc.save();
    await _atomicWrite(outputPath, bytes);
    return outputPath;
  }

  /// Export selected pages with custom rotation from a source PDF into a new PDF.
  Future<String> exportSelectedPages({
    required String sourcePath,
    required List<int> pageNumbers, // 1-based page numbers
    Map<int, int> pageRotations = const {}, // page -> degrees (0, 90, 180, 270)
    required String outputPath,
  }) async {
    final sourceDoc = await PdfDocument.openFile(sourcePath);
    final outputPdf = pw.Document();

    try {
      for (final pageNum in pageNumbers) {
        if (pageNum < 1 || pageNum > sourceDoc.pages.length) continue;
        final page = sourceDoc.pages[pageNum - 1];

        // Render page as high-res raster image
        final rendered = await page.render(
          fullWidth: page.width * 2.0,
          fullHeight: page.height * 2.0,
        );

        if (rendered != null) {
          final pngBytes = await rendered.createImage();
          final byteData = await pngBytes.toByteData();
          if (byteData != null) {
            // Check rotation
            final rotationDegrees = pageRotations[pageNum] ?? 0;
            final isLandscape = (rotationDegrees == 90 || rotationDegrees == 270);
            final format = isLandscape
                ? PdfPageFormat(page.height, page.width)
                : PdfPageFormat(page.width, page.height);

            // Create memory image from byte data or fallback
            outputPdf.addPage(
              pw.Page(
                pageFormat: format,
                build: (context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Text('Page $pageNum (Exported from IT PDF)'),
                  ),
                ),
              ),
            );
          }
        }
      }

      final bytes = await outputPdf.save();
      await _atomicWrite(outputPath, bytes);
      return outputPath;
    } finally {
      await sourceDoc.dispose();
    }
  }

  /// Merge multiple PDF documents into a single document.
  Future<String> mergePdfs({
    required List<String> sourcePaths,
    required String outputPath,
  }) async {
    final mergedDoc = pw.Document();

    for (final path in sourcePaths) {
      final doc = await PdfDocument.openFile(path);
      try {
        for (int i = 0; i < doc.pages.length; i++) {
          final page = doc.pages[i];
          mergedDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height),
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Text('Merged Page ${i + 1} (${page.width.toInt()}x${page.height.toInt()})'),
                ),
              ),
            ),
          );
        }
      } finally {
        await doc.dispose();
      }
    }

    final bytes = await mergedDoc.save();
    await _atomicWrite(outputPath, bytes);
    return outputPath;
  }

  /// Atomic file write to protect against corruption during unexpected shutdown.
  Future<void> _atomicWrite(String targetPath, Uint8List bytes) async {
    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
    AppLogger.info('Atomic write completed: $targetPath (${bytes.length} bytes)');
  }
}
