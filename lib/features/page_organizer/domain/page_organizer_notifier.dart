import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Riverpod Notifier managing page reordering, rotation, deletion and extraction.
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
      final currentRot = updated[index].rotationDegrees;
      final newRot = (currentRot + degrees) % 360;
      updated[index] = updated[index].copyWith(rotationDegrees: newRot);
      state = state.copyWith(pages: updated, isDirty: true);
    }
  }

  void rotateSelected(int degrees) {
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
    final list = List<PageItem>.from(state.pages);
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(target, item);

    final reindexed = List.generate(
      list.length,
      (i) => list[i].copyWith(currentPosition: i),
    );

    state = state.copyWith(pages: reindexed, isDirty: true);
  }

  void deleteSelected() {
    final remaining = state.pages.where((p) => !p.isSelected).toList();
    final reindexed = List.generate(
      remaining.length,
      (i) => remaining[i].copyWith(currentPosition: i),
    );
    state = state.copyWith(pages: reindexed, isDirty: true);
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
