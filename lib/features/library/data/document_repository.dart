import 'dart:io';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../shared/models/document_meta.dart';
import '../domain/i_document_repository.dart';

/// Concrete implementation of IDocumentRepository.
class DocumentRepository implements IDocumentRepository {
  final PreferencesService _preferencesService;

  DocumentRepository(this._preferencesService);

  @override
  Future<List<DocumentMeta>> getDocuments() async {
    return _preferencesService.loadDocuments();
  }

  @override
  Future<void> saveDocument(DocumentMeta document) async {
    final docs = _preferencesService.loadDocuments();
    final index = docs.indexWhere((d) => d.id == document.id);
    if (index >= 0) {
      docs[index] = document;
    } else {
      docs.insert(0, document);
    }
    await _preferencesService.saveDocuments(docs);
  }

  @override
  Future<void> removeDocument(
    String id, {
    bool deleteSourceFile = false,
  }) async {
    final docs = _preferencesService.loadDocuments();
    final targetIndex = docs.indexWhere((d) => d.id == id);
    if (targetIndex < 0) return;

    final targetDoc = docs[targetIndex];
    docs.removeAt(targetIndex);
    await _preferencesService.saveDocuments(docs);

    if (deleteSourceFile) {
      try {
        final file = File(targetDoc.path);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('Source file removed: ${targetDoc.path}');
        }
      } catch (e, st) {
        AppLogger.error(
          'Failed to delete source file on disk',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final docs = _preferencesService.loadDocuments();
    final index = docs.indexWhere((d) => d.id == id);
    if (index >= 0) {
      docs[index] = docs[index].copyWith(isFavorite: !docs[index].isFavorite);
      await _preferencesService.saveDocuments(docs);
    }
  }

  @override
  Future<void> updateReadingProgress(
    String id,
    int page,
    int totalPages,
  ) async {
    final docs = _preferencesService.loadDocuments();
    final index = docs.indexWhere((d) => d.id == id);
    if (index >= 0) {
      docs[index] = docs[index].copyWith(
        lastPageRead: page,
        totalPages: totalPages > 0 ? totalPages : docs[index].totalPages,
        lastOpened: DateTime.now(),
      );
      await _preferencesService.saveDocuments(docs);
    }
  }

  @override
  Future<void> renameDocument(String id, String newName) async {
    final docs = _preferencesService.loadDocuments();
    final index = docs.indexWhere((d) => d.id == id);
    if (index >= 0) {
      docs[index] = docs[index].copyWith(name: newName);
      await _preferencesService.saveDocuments(docs);
    }
  }

  @override
  Future<void> setFolder(String id, String? folder) async {
    final docs = _preferencesService.loadDocuments();
    final index = docs.indexWhere((d) => d.id == id);
    if (index >= 0) {
      docs[index] = docs[index].copyWith(folder: folder);
      await _preferencesService.saveDocuments(docs);
    }
  }
}
