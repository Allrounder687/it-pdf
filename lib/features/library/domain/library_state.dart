import '../../../shared/models/document_meta.dart';

/// Sort options for documents in the library.
enum LibrarySortOption { lastOpened, name, size, dateAdded }

/// State representation for the document library.
class LibraryState {
  final List<DocumentMeta> documents;
  final String searchQuery;
  final String? filterFolder;
  final Set<String> selectedIds;
  final bool isGridView;
  final LibrarySortOption sortBy;
  final bool sortAscending;
  final bool isLoading;
  final String? errorMessage;

  const LibraryState({
    this.documents = const [],
    this.searchQuery = '',
    this.filterFolder,
    this.selectedIds = const {},
    this.isGridView = true,
    this.sortBy = LibrarySortOption.lastOpened,
    this.sortAscending = false,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Filtered and sorted documents list.
  List<DocumentMeta> get visibleDocuments {
    var result = List<DocumentMeta>.from(documents);

    // Apply folder filter
    if (filterFolder != null && filterFolder!.isNotEmpty) {
      result = result.where((d) => d.folder == filterFolder).toList();
    }

    // Apply search query
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase().trim();
      result = result.where((d) {
        final matchesName = d.name.toLowerCase().contains(query);
        final matchesTags = d.tags.any((t) => t.toLowerCase().contains(query));
        return matchesName || matchesTags;
      }).toList();
    }

    // Apply sorting
    result.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case LibrarySortOption.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case LibrarySortOption.size:
          cmp = a.sizeInBytes.compareTo(b.sizeInBytes);
          break;
        case LibrarySortOption.dateAdded:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case LibrarySortOption.lastOpened:
          cmp = a.lastOpened.compareTo(b.lastOpened);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });

    return result;
  }

  /// Recent documents for Continue Reading.
  List<DocumentMeta> get recentDocuments {
    final list = List<DocumentMeta>.from(documents);
    list.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return list.take(10).toList();
  }

  /// Favorite documents.
  List<DocumentMeta> get favoriteDocuments {
    return documents.where((d) => d.isFavorite).toList();
  }

  /// All unique folders.
  List<String> get availableFolders {
    final folders = <String>{};
    for (final doc in documents) {
      if (doc.folder != null && doc.folder!.isNotEmpty) {
        folders.add(doc.folder!);
      }
    }
    return folders.toList()..sort();
  }

  LibraryState copyWith({
    List<DocumentMeta>? documents,
    String? searchQuery,
    String? filterFolder,
    Set<String>? selectedIds,
    bool? isGridView,
    LibrarySortOption? sortBy,
    bool? sortAscending,
    bool? isLoading,
    String? errorMessage,
    bool clearFolder = false,
  }) {
    return LibraryState(
      documents: documents ?? this.documents,
      searchQuery: searchQuery ?? this.searchQuery,
      filterFolder: clearFolder ? null : (filterFolder ?? this.filterFolder),
      selectedIds: selectedIds ?? this.selectedIds,
      isGridView: isGridView ?? this.isGridView,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
