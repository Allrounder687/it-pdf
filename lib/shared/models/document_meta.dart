import 'dart:convert';

/// Metadata representation of a managed PDF document in the library.
class DocumentMeta {
  final String id;
  final String name;
  final String path;
  final int sizeInBytes;
  final DateTime lastOpened;
  final int lastPageRead;
  final int totalPages;
  final bool isFavorite;
  final String? folder;
  final DateTime createdAt;
  final List<String> tags;

  const DocumentMeta({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeInBytes,
    required this.lastOpened,
    this.lastPageRead = 1,
    this.totalPages = 1,
    this.isFavorite = false,
    this.folder,
    required this.createdAt,
    this.tags = const [],
  });

  /// Formatted file size string (KB / MB).
  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Copy with modifications.
  DocumentMeta copyWith({
    String? id,
    String? name,
    String? path,
    int? sizeInBytes,
    DateTime? lastOpened,
    int? lastPageRead,
    int? totalPages,
    bool? isFavorite,
    String? folder,
    DateTime? createdAt,
    List<String>? tags,
  }) {
    return DocumentMeta(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastOpened: lastOpened ?? this.lastOpened,
      lastPageRead: lastPageRead ?? this.lastPageRead,
      totalPages: totalPages ?? this.totalPages,
      isFavorite: isFavorite ?? this.isFavorite,
      folder: folder ?? this.folder,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'sizeInBytes': sizeInBytes,
      'lastOpened': lastOpened.toIso8601String(),
      'lastPageRead': lastPageRead,
      'totalPages': totalPages,
      'isFavorite': isFavorite,
      'folder': folder,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory DocumentMeta.fromMap(Map<String, dynamic> map) {
    return DocumentMeta(
      id: map['id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      sizeInBytes: (map['sizeInBytes'] as num?)?.toInt() ?? 0,
      lastOpened: DateTime.tryParse(map['lastOpened'] as String? ?? '') ?? DateTime.now(),
      lastPageRead: (map['lastPageRead'] as num?)?.toInt() ?? 1,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      isFavorite: map['isFavorite'] as bool? ?? false,
      folder: map['folder'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      tags: List<String>.from(map['tags'] as List? ?? const []),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DocumentMeta.fromJson(String source) =>
      DocumentMeta.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
