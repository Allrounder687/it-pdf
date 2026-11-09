/// Layout modes for the PDF Reader.
enum ReaderLayout {
  continuousVertical,
  continuousHorizontal,
  singlePage,
  twoPage,
}

/// Reading theme modes for comfortable reading.
enum ReaderThemeMode { light, dark, sepia, night }

/// State representation for the active PDF Reader session.
class ReaderState {
  final String documentPath;
  final String documentId;
  final String documentName;
  final int currentPage;
  final int pageCount;
  final double currentZoom;
  final ReaderLayout layout;
  final ReaderThemeMode themeMode;
  final bool showControls;
  final bool showThumbnails;
  final bool showOutline;
  final bool showSearch;
  final String searchQuery;
  final int searchMatchCount;
  final int currentSearchIndex;
  final bool isFitWidth;
  final bool isLoading;
  final String? errorMessage;

  const ReaderState({
    required this.documentPath,
    required this.documentId,
    required this.documentName,
    this.currentPage = 1,
    this.pageCount = 1,
    this.currentZoom = 1.0,
    this.layout = ReaderLayout.continuousVertical,
    this.themeMode = ReaderThemeMode.light,
    this.showControls = true,
    this.showThumbnails = false,
    this.showOutline = false,
    this.showSearch = false,
    this.searchQuery = '',
    this.searchMatchCount = 0,
    this.currentSearchIndex = 0,
    this.isFitWidth = true,
    this.isLoading = false,
    this.errorMessage,
  });

  ReaderState copyWith({
    String? documentPath,
    String? documentId,
    String? documentName,
    int? currentPage,
    int? pageCount,
    double? currentZoom,
    ReaderLayout? layout,
    ReaderThemeMode? themeMode,
    bool? showControls,
    bool? showThumbnails,
    bool? showOutline,
    bool? showSearch,
    String? searchQuery,
    int? searchMatchCount,
    int? currentSearchIndex,
    bool? isFitWidth,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReaderState(
      documentPath: documentPath ?? this.documentPath,
      documentId: documentId ?? this.documentId,
      documentName: documentName ?? this.documentName,
      currentPage: currentPage ?? this.currentPage,
      pageCount: pageCount ?? this.pageCount,
      currentZoom: currentZoom ?? this.currentZoom,
      layout: layout ?? this.layout,
      themeMode: themeMode ?? this.themeMode,
      showControls: showControls ?? this.showControls,
      showThumbnails: showThumbnails ?? this.showThumbnails,
      showOutline: showOutline ?? this.showOutline,
      showSearch: showSearch ?? this.showSearch,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatchCount: searchMatchCount ?? this.searchMatchCount,
      currentSearchIndex: currentSearchIndex ?? this.currentSearchIndex,
      isFitWidth: isFitWidth ?? this.isFitWidth,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
