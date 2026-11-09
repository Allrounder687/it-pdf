import 'dart:io';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import '../../../core/pdf_engine/syncfusion_pdf_service.dart';
import '../../../core/storage/safe_document_storage.dart';
import 'page_item.dart';

/// High-performance PDF assembly, page extraction, image conversion and merge service.
/// Powered by the Syncfusion ISO 32000 Vector Engine and SafeDocumentStorage.
class PageOrganizerService {
  final SyncfusionPdfService _syncfusionService;
  final SafeDocumentStorage _safeStorage;

  PageOrganizerService({
    SyncfusionPdfService? syncfusionService,
    SafeDocumentStorage? safeStorage,
  }) : _syncfusionService = syncfusionService ?? SyncfusionPdfService(),
       _safeStorage = safeStorage ?? SafeDocumentStorage();

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
              child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            );
          },
        ),
      );
    }

    final bytes = await pdfDoc.save();
    final result = await _safeStorage.transactionalSaveBytes(
      targetPath: outputPath,
      bytes: bytes,
    );
    if (!result.isSuccess) {
      throw StateError(result.errorMessage ?? 'Images to PDF failed');
    }
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
    final result = await _safeStorage.transactionalSaveBytes(
      targetPath: outputPath,
      bytes: bytes,
    );
    if (!result.isSuccess) {
      throw StateError(result.errorMessage ?? 'Create blank document failed');
    }
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

  /// Commits workspace page organizer changes (reordering, rotation, deletion)
  /// back into the document using transactional safe saving.
  Future<String> applyOrganizerChanges({
    required String sourcePath,
    required List<PageItem> workspacePages,
    required int originalPageCount,
    required String outputPath,
  }) async {
    if (workspacePages.isEmpty) {
      throw StateError(
        'Cannot apply organizer changes: document must contain at least one page.',
      );
    }

    // Check if the page sequence is strictly a subset in original order (no reordering)
    bool isMonotonic = true;
    for (int i = 1; i < workspacePages.length; i++) {
      if (workspacePages[i].originalPageNumber <=
          workspacePages[i - 1].originalPageNumber) {
        isMonotonic = false;
        break;
      }
    }

    if (isMonotonic && workspacePages.length <= originalPageCount) {
      // 1. Determine deleted pages
      final remainingOriginalNums = workspacePages
          .map((p) => p.originalPageNumber)
          .toSet();
      final deletedPageNums = <int>[];
      for (int i = 1; i <= originalPageCount; i++) {
        if (!remainingOriginalNums.contains(i)) {
          deletedPageNums.add(i);
        }
      }

      // 2. Determine rotations
      final pageRotations = <int, int>{};
      for (final p in workspacePages) {
        if (p.rotationDegrees > 0) {
          pageRotations[p.originalPageNumber] = p.rotationDegrees;
        }
      }

      // If only rotations/deletions occurred, use surgical lossless extraction/deletion
      return await _syncfusionService.extractPages(
        sourcePath: sourcePath,
        pageNumbers: workspacePages.map((p) => p.originalPageNumber).toList(),
        pageRotations: pageRotations,
        outputPath: outputPath,
      );
    }

    // If reordering or duplication occurred, extract according to custom page list
    final pageNums = workspacePages.map((p) => p.originalPageNumber).toList();
    final rotations = {
      for (final p in workspacePages) p.originalPageNumber: p.rotationDegrees,
    };

    return await _syncfusionService.extractPages(
      sourcePath: sourcePath,
      pageNumbers: pageNums,
      pageRotations: rotations,
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
}
