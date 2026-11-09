import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/providers.dart';
import '../../../shared/models/document_meta.dart';
import '../data/document_repository.dart';
import 'i_document_repository.dart';
import 'library_state.dart';

/// Provider for document repository.
final documentRepositoryProvider = Provider<IDocumentRepository>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return DocumentRepository(prefsService);
});

/// Riverpod Notifier managing the document library.
class LibraryNotifier extends Notifier<LibraryState> {
  static const _uuid = Uuid();

  IDocumentRepository get _repository => ref.read(documentRepositoryProvider);
  FilePickerService get _filePicker => ref.read(filePickerServiceProvider);

  @override
  LibraryState build() {
    Future.microtask(() => loadLibrary());
    return const LibraryState();
  }

  /// Load all documents from disk.
  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final docs = await _repository.getDocuments();
      state = state.copyWith(documents: docs, isLoading: false);
    } catch (e, st) {
      AppLogger.error('Failed to load library', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load documents: $e',
      );
    }
  }

  /// Import a PDF file into the library.
  Future<DocumentMeta?> importFileFromPath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File does not exist at $path');
      }

      final fileName = p.basename(path);
      final fileSize = await file.length();

      // Check if document already exists in registry
      final existingIndex = state.documents.indexWhere((d) => d.path == path);
      if (existingIndex >= 0) {
        final existing = state.documents[existingIndex].copyWith(
          lastOpened: DateTime.now(),
          sizeInBytes: fileSize,
        );
        await _repository.saveDocument(existing);
        await loadLibrary();
        return existing;
      }

      final newDoc = DocumentMeta(
        id: _uuid.v4(),
        name: fileName,
        path: path,
        sizeInBytes: fileSize,
        lastOpened: DateTime.now(),
        lastPageRead: 1,
        totalPages: 1,
        createdAt: DateTime.now(),
      );

      await _repository.saveDocument(newDoc);
      await loadLibrary();
      return newDoc;
    } catch (e, st) {
      AppLogger.error('Failed to import file', error: e, stackTrace: st);
      state = state.copyWith(errorMessage: 'Could not import PDF: $e');
      return null;
    }
  }

  /// Launch native file picker and import the selected PDF.
  Future<DocumentMeta?> pickAndImportPdf() async {
    final pickedPath = await _filePicker.pickPdfFile();
    if (pickedPath != null) {
      return await importFileFromPath(pickedPath);
    }
    return null;
  }

  /// Toggle document favorite status.
  Future<void> toggleFavorite(String id) async {
    await _repository.toggleFavorite(id);
    await loadLibrary();
  }

  /// Update reading position.
  Future<void> updateReadingProgress(String id, int page, int totalPages) async {
    await _repository.updateReadingProgress(id, page, totalPages);
    await loadLibrary();
  }

  /// Rename document.
  Future<void> renameDocument(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    await _repository.renameDocument(id, trimmed);
    await loadLibrary();
  }

  /// Assign folder category.
  Future<void> setFolder(String id, String? folder) async {
    await _repository.setFolder(id, folder?.trim().isEmpty == true ? null : folder?.trim());
    await loadLibrary();
  }

  /// Delete document from library.
  Future<void> deleteDocument(String id, {bool deleteSourceFile = false}) async {
    await _repository.removeDocument(id, deleteSourceFile: deleteSourceFile);
    final updatedSelected = Set<String>.from(state.selectedIds)..remove(id);
    state = state.copyWith(selectedIds: updatedSelected);
    await loadLibrary();
  }

  /// Batch delete selected documents.
  Future<void> batchDeleteSelected({bool deleteSourceFile = false}) async {
    for (final id in state.selectedIds) {
      await _repository.removeDocument(id, deleteSourceFile: deleteSourceFile);
    }
    state = state.copyWith(selectedIds: const {});
    await loadLibrary();
  }

  /// Selection management.
  void toggleSelect(String id) {
    final current = Set<String>.from(state.selectedIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedIds: current);
  }

  void selectAll() {
    final allIds = state.visibleDocuments.map((d) => d.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: const {});
  }

  /// Filtering and search.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterFolder(String? folder) {
    state = state.copyWith(filterFolder: folder, clearFolder: folder == null);
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void setSortOption(LibrarySortOption option) {
    if (state.sortBy == option) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortBy: option, sortAscending: false);
    }
  }
}

/// Provider for LibraryNotifier.
final libraryNotifierProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);
