import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reader_state.dart';
import '../../library/domain/library_notifier.dart';

/// Parameters for creating a reader session.
class ReaderNotifierParams {
  final String id;
  final String name;
  final String path;
  final int initialPage;
  final int initialPageCount;

  const ReaderNotifierParams({
    required this.id,
    required this.name,
    required this.path,
    this.initialPage = 1,
    this.initialPageCount = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderNotifierParams &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;
}

/// Notifier controlling the active PDF reader document session.
class ReaderNotifier extends Notifier<ReaderState> {
  final ReaderNotifierParams params;

  ReaderNotifier(this.params);

  @override
  ReaderState build() {
    return ReaderState(
      documentPath: params.path,
      documentId: params.id,
      documentName: params.name,
      currentPage: params.initialPage,
      pageCount: params.initialPageCount,
    );
  }

  void setPage(int page) {
    if (page == state.currentPage) return;
    state = state.copyWith(currentPage: page);
    ref
        .read(libraryNotifierProvider.notifier)
        .updateReadingProgress(state.documentId, page, state.pageCount);
  }

  void setPageCount(int count) {
    if (count == state.pageCount) return;
    state = state.copyWith(pageCount: count);
    ref
        .read(libraryNotifierProvider.notifier)
        .updateReadingProgress(state.documentId, state.currentPage, count);
  }

  void setZoom(double zoom) {
    state = state.copyWith(currentZoom: zoom);
  }

  void setLayout(ReaderLayout layout) {
    state = state.copyWith(layout: layout);
  }

  void setThemeMode(ReaderThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleThumbnails() {
    state = state.copyWith(
      showThumbnails: !state.showThumbnails,
      showOutline: false,
    );
  }

  void toggleOutline() {
    state = state.copyWith(
      showOutline: !state.showOutline,
      showThumbnails: false,
    );
  }

  void toggleSearch() {
    final nextSearch = !state.showSearch;
    state = state.copyWith(
      showSearch: nextSearch,
      searchQuery: nextSearch ? state.searchQuery : '',
      searchMatchCount: nextSearch ? state.searchMatchCount : 0,
      currentSearchIndex: 0,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSearchResults(int count, int index) {
    state = state.copyWith(searchMatchCount: count, currentSearchIndex: index);
  }
}

/// Family provider for ReaderNotifier scoped to document parameters.
final readerNotifierProvider =
    NotifierProvider.family<ReaderNotifier, ReaderState, ReaderNotifierParams>(
      ReaderNotifier.new,
    );
