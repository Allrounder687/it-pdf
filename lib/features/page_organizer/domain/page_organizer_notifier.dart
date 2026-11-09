import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../library/domain/library_notifier.dart';
import 'page_item.dart';
import 'page_organizer_service.dart';
import 'page_organizer_state.dart';

/// Provider for PageOrganizerService.
final pageOrganizerServiceProvider = Provider<PageOrganizerService>((ref) {
  return PageOrganizerService();
});

/// Parameters for initializing the page organizer notifier.
class PageOrganizerParams {
  final String path;
  final String id;
  final String name;
  final int pageCount;

  const PageOrganizerParams({
    required this.path,
    required this.id,
    required this.name,
    required this.pageCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageOrganizerParams &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;
}

/// Riverpod Notifier managing page reordering, rotation, deletion, insertion and extraction.
class PageOrganizerNotifier extends Notifier<PageOrganizerState> {
  final PageOrganizerParams params;

  PageOrganizerNotifier(this.params);

  PageOrganizerService get _service => ref.read(pageOrganizerServiceProvider);

  @override
  PageOrganizerState build() {
    final list = List.generate(
      params.pageCount,
      (i) => PageItem(
        originalPageNumber: i + 1,
        currentPosition: i,
      ),
    );
    return PageOrganizerState(
      documentPath: params.path,
      documentId: params.id,
      documentName: params.name,
      pages: list,
    );
  }

  void _pushUndoSnapshot() {
    final updatedUndo = List<List<PageItem>>.from(state.undoStack)..add(state.pages);
    if (updatedUndo.length > 25) {
      updatedUndo.removeAt(0);
    }
    state = state.copyWith(undoStack: updatedUndo, redoStack: const []);
  }

  void toggleSelect(int index) {
    final updated = List<PageItem>.from(state.pages);
    if (index >= 0 && index < updated.length) {
      updated[index] = updated[index].copyWith(isSelected: !updated[index].isSelected);
      state = state.copyWith(pages: updated);
    }
  }

  void selectAll() {
    final updated = state.pages.map((p) => p.copyWith(isSelected: true)).toList();
    state = state.copyWith(pages: updated);
  }

  void clearSelection() {
    final updated = state.pages.map((p) => p.copyWith(isSelected: false)).toList();
    state = state.copyWith(pages: updated);
  }

  void rotatePage(int index, int degrees) {
    final updated = List<PageItem>.from(state.pages);
    if (index >= 0 && index < updated.length) {
      _pushUndoSnapshot();
      final currentRot = updated[index].rotationDegrees;
      final newRot = (currentRot + degrees) % 360;
      updated[index] = updated[index].copyWith(rotationDegrees: newRot);
      state = state.copyWith(pages: updated, isDirty: true);
    }
  }

  void rotateSelected(int degrees) {
    if (state.selectedPages.isEmpty) return;
    _pushUndoSnapshot();
    final updated = state.pages.map((p) {
      if (p.isSelected) {
        final newRot = (p.rotationDegrees + degrees) % 360;
        return p.copyWith(rotationDegrees: newRot);
      }
      return p;
    }).toList();
    state = state.copyWith(pages: updated, isDirty: true);
  }

  void reorderPage(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.pages.length) return;
    _pushUndoSnapshot();
    final list = List<PageItem>.from(state.pages);
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    target = target.clamp(0, list.length - 1);
    final item = list.removeAt(oldIndex);
    list.insert(target, item);

    final reindexed = List.generate(
      list.length,
      (i) => list[i].copyWith(currentPosition: i),
    );

    state = state.copyWith(pages: reindexed, isDirty: true);
  }

  void deleteSelected() {
    if (state.selectedPages.isEmpty) return;
    if (state.selectedPages.length == state.pages.length) {
      // Prevent deleting ALL pages
      state = state.copyWith(errorMessage: 'A PDF document must contain at least one page.');
      return;
    }

    _pushUndoSnapshot();
    final remaining = state.pages.where((p) => !p.isSelected).toList();
    final reindexed = List.generate(
      remaining.length,
      (i) => remaining[i].copyWith(currentPosition: i),
    );
    state = state.copyWith(pages: reindexed, isDirty: true);
  }

  void duplicateSelected() {
    if (state.selectedPages.isEmpty) return;
    _pushUndoSnapshot();
    final list = <PageItem>[];
    for (final page in state.pages) {
      list.add(page);
      if (page.isSelected) {
        list.add(page.copyWith(isSelected: false));
      }
    }
    final reindexed = List.generate(
      list.length,
      (i) => list[i].copyWith(currentPosition: i),
    );
    state = state.copyWith(pages: reindexed, isDirty: true);
  }

  void insertPageAt(int index, PageItem newItem) {
    _pushUndoSnapshot();
    final list = List<PageItem>.from(state.pages);
    final target = index.clamp(0, list.length);
    list.insert(target, newItem);
    final reindexed = List.generate(
      list.length,
      (i) => list[i].copyWith(currentPosition: i),
    );
    state = state.copyWith(pages: reindexed, isDirty: true);
  }

  void undo() {
    if (!state.canUndo) return;
    final previousPages = state.undoStack.last;
    final updatedUndo = List<List<PageItem>>.from(state.undoStack)..removeLast();
    final updatedRedo = List<List<PageItem>>.from(state.redoStack)..add(state.pages);

    state = state.copyWith(
      pages: previousPages,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      isDirty: true,
    );
  }

  void redo() {
    if (!state.canRedo) return;
    final nextPages = state.redoStack.last;
    final updatedRedo = List<List<PageItem>>.from(state.redoStack)..removeLast();
    final updatedUndo = List<List<PageItem>>.from(state.undoStack)..add(state.pages);

    state = state.copyWith(
      pages: nextPages,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      isDirty: true,
    );
  }

  void cancelChanges() {
    final list = List.generate(
      params.pageCount,
      (i) => PageItem(
        originalPageNumber: i + 1,
        currentPosition: i,
      ),
    );
    state = state.copyWith(
      pages: list,
      isDirty: false,
      undoStack: const [],
      redoStack: const [],
    );
  }

  /// Commits all workspace edits to the PDF file using safe transactional storage.
  Future<bool> applyChanges() async {
    if (!state.isDirty) return true;
    if (state.pages.isEmpty) {
      state = state.copyWith(errorMessage: 'Cannot save document with 0 pages.');
      return false;
    }

    state = state.copyWith(isProcessing: true, statusMessage: 'Saving changes safely...');
    try {
      await _service.applyOrganizerChanges(
        sourcePath: state.documentPath,
        workspacePages: state.pages,
        originalPageCount: params.pageCount,
        outputPath: state.documentPath,
      );

      // Invalidate cached thumbnails for this document
      PdfThumbnailCache.instance.invalidateDocument(state.documentPath);

      // Update library progress
      ref.read(libraryNotifierProvider.notifier).updateReadingProgress(
            state.documentId,
            1,
            state.pages.length,
          );

      state = state.copyWith(
        isProcessing: false,
        isDirty: false,
        statusMessage: 'Document changes saved!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to apply changes: $e',
      );
      return false;
    }
  }

  Future<bool> exportSelected({required String outputPath}) async {
    final selected = state.selectedPages;
    if (selected.isEmpty) return false;

    state = state.copyWith(isProcessing: true, statusMessage: 'Exporting selected pages...');
    try {
      final pageNums = selected.map((p) => p.originalPageNumber).toList();
      final rotations = {
        for (final p in selected) p.originalPageNumber: p.rotationDegrees,
      };

      await _service.exportSelectedPages(
        sourcePath: state.documentPath,
        pageNumbers: pageNums,
        pageRotations: rotations,
        outputPath: outputPath,
      );

      state = state.copyWith(isProcessing: false, statusMessage: 'Export successful!');
      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Export failed: $e',
      );
      return false;
    }
  }
}

/// Family provider for PageOrganizerNotifier.
final pageOrganizerNotifierProvider = NotifierProvider.family<
    PageOrganizerNotifier, PageOrganizerState, PageOrganizerParams>(PageOrganizerNotifier.new);
