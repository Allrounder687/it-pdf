import '../../../shared/models/document_meta.dart';
import 'reader_notifier.dart';

/// Represents an active document tab in the desktop workspace.
class DocumentTab {
  final String id;
  final String name;
  final String path;
  final int initialPage;
  final int totalPages;
  final DateTime openedAt;
  final bool isDirty;

  const DocumentTab({
    required this.id,
    required this.name,
    required this.path,
    this.initialPage = 1,
    this.totalPages = 1,
    required this.openedAt,
    this.isDirty = false,
  });

  ReaderNotifierParams get readerParams => ReaderNotifierParams(
    id: id,
    name: name,
    path: path,
    initialPage: initialPage,
    initialPageCount: totalPages,
  );

  factory DocumentTab.fromMeta(DocumentMeta meta) {
    return DocumentTab(
      id: meta.id,
      name: meta.name,
      path: meta.path,
      initialPage: meta.lastPageRead,
      totalPages: meta.totalPages,
      openedAt: DateTime.now(),
      isDirty: false,
    );
  }

  DocumentTab copyWith({
    String? id,
    String? name,
    String? path,
    int? initialPage,
    int? totalPages,
    DateTime? openedAt,
    bool? isDirty,
  }) {
    return DocumentTab(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      initialPage: initialPage ?? this.initialPage,
      totalPages: totalPages ?? this.totalPages,
      openedAt: openedAt ?? this.openedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentTab &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;
}
