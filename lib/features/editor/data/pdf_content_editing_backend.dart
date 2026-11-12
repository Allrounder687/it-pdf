import '../domain/pdf_content_object.dart';
import '../domain/pdf_edit_transaction.dart';

/// Clean interface abstracting low-level PDF content manipulation backends.
abstract class PdfContentEditingBackend {
  /// Extracts all authentic page content objects (text, paths, images) for the given page.
  Future<List<PdfContentObject>> extractPageObjects({
    required String filePath,
    required int pageIndex,
  });

  /// Groups coherent text lines into semantic paragraphs.
  Future<List<PdfParagraphBlock>> extractParagraphs({
    required String filePath,
    required int pageIndex,
  });

  /// Applies all content object mutations, additions, and deletions and writes
  /// out a valid, complete ISO 32000 PDF document.
  Future<String> commitModifications({
    required String sourcePath,
    required String targetPath,
    required Map<int, List<PdfContentObject>> modifiedPagesObjects,
    required List<PdfEditOperation> operations,
  });

  /// Verifies that a target PDF file is valid, non-corrupted, and can be rendered.
  Future<bool> verifyPdfIntegrity({required String filePath});

  /// Detects whether the PDF contains digital signatures or certification permissions.
  Future<bool> hasDigitalSignatures({required String filePath});
}
