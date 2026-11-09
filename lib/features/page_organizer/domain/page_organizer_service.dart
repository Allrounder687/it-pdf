import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import '../../../core/logging/app_logger.dart';
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';

/// High-performance PDF assembly, page extraction, image conversion and merge service.
/// Powered by the Syncfusion ISO 32000 Vector Engine.
class PageOrganizerService {
  final SyncfusionPdfService _syncfusionService;

  PageOrganizerService({SyncfusionPdfService? syncfusionService})
      : _syncfusionService = syncfusionService ?? SyncfusionPdfService();

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

  /// Export selected pages with custom rotation from a source PDF into a new PDF
  /// preserving original vector paths, TrueType fonts, resolution and layout.
  Future<String> exportSelectedPages({
    required String sourcePath,
    required List<int> pageNumbers, // 1-based page numbers
    Map<int, int> pageRotations = const {}, // page -> degrees (0, 90, 180, 270)
    required String outputPath,
  }) async {
    return await _syncfusionService.extractPages(
      sourcePath: sourcePath,
      pageNumbers: pageNumbers,
      pageRotations: pageRotations,
      outputPath: outputPath,
    );
  }

  /// Merge multiple PDF documents into a single document preserving vector resolution.
  Future<String> mergePdfs({
    required List<String> sourcePaths,
    required String outputPath,
  }) async {
    return await _syncfusionService.mergePdfs(
      sourcePaths: sourcePaths,
      outputPath: outputPath,
    );
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
