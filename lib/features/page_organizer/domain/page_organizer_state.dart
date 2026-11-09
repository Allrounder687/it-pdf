import 'page_item.dart';

/// State representation for page organization workspace.
class PageOrganizerState {
  final String documentPath;
  final String documentId;
  final String documentName;
  final List<PageItem> pages;
  final bool isProcessing;
  final String? statusMessage;
  final String? errorMessage;
  final bool isDirty;

  const PageOrganizerState({
    required this.documentPath,
    required this.documentId,
    required this.documentName,
    this.pages = const [],
    this.isProcessing = false,
    this.statusMessage,
    this.errorMessage,
    this.isDirty = false,
  });

  /// Selected page items.
  List<PageItem> get selectedPages => pages.where((p) => p.isSelected).toList();

  PageOrganizerState copyWith({
    String? documentPath,
    String? documentId,
    String? documentName,
    List<PageItem>? pages,
    bool? isProcessing,
    String? statusMessage,
    String? errorMessage,
    bool? isDirty,
  }) {
    return PageOrganizerState(
      documentPath: documentPath ?? this.documentPath,
      documentId: documentId ?? this.documentId,
      documentName: documentName ?? this.documentName,
      pages: pages ?? this.pages,
      isProcessing: isProcessing ?? this.isProcessing,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
