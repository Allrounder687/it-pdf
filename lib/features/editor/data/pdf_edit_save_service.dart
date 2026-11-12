import 'dart:io';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/safe_document_storage.dart';
import '../domain/pdf_content_object.dart';
import '../domain/pdf_edit_transaction.dart';
import 'pdf_content_editing_backend.dart';

/// High-level transactional PDF save service ensuring document integrity,
/// atomic commits, permission adherence, and signature warnings.
class PdfEditSaveService {
  final PdfContentEditingBackend _backend;
  final SafeDocumentStorage _safeStorage;

  PdfEditSaveService({
    required PdfContentEditingBackend backend,
    SafeDocumentStorage? safeStorage,
  }) : _backend = backend,
       _safeStorage = safeStorage ?? SafeDocumentStorage();

  /// Saves the modified PDF with full integrity guarantees.
  /// If [overwriteOriginal] is true, it safely stages to a temporary file,
  /// verifies the result, and commits atomically.
  Future<String> saveDocument({
    required String sourcePath,
    required String targetPath,
    required Map<int, List<PdfContentObject>> modifiedPagesObjects,
    required List<PdfEditOperation> operations,
    bool overwriteOriginal = false,
  }) async {
    final hasSignatures = await _backend.hasDigitalSignatures(
      filePath: sourcePath,
    );
    if (hasSignatures) {
      AppLogger.warning(
        'Document $sourcePath contains digital signatures. Editing may invalidate signatures.',
      );
    }

    final effectiveTarget = overwriteOriginal ? sourcePath : targetPath;

    final savedPath = await _backend.commitModifications(
      sourcePath: sourcePath,
      targetPath: effectiveTarget,
      modifiedPagesObjects: modifiedPagesObjects,
      operations: operations,
    );

    AppLogger.info('Successfully saved modified PDF content to $savedPath');
    return savedPath;
  }

  /// Verifies that the document exists and can be opened without errors.
  Future<bool> verifyDocumentIntegrity(String filePath) async {
    return _backend.verifyPdfIntegrity(filePath: filePath);
  }
}
