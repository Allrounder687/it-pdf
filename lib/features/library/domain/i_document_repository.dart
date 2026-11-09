import '../../../shared/models/document_meta.dart';

/// Contract for document library repository operations.
abstract class IDocumentRepository {
  /// Fetch all registered documents.
  Future<List<DocumentMeta>> getDocuments();

  /// Save or update a document in registry.
  Future<void> saveDocument(DocumentMeta document);

  /// Remove a document by ID with safeguard against deleting user files.
  Future<void> removeDocument(String id, {bool deleteSourceFile = false});

  /// Toggle document favorite status.
  Future<void> toggleFavorite(String id);

  /// Update reading position and total page count.
  Future<void> updateReadingProgress(String id, int page, int totalPages);

  /// Rename document title.
  Future<void> renameDocument(String id, String newName);

  /// Assign folder category.
  Future<void> setFolder(String id, String? folder);
}
