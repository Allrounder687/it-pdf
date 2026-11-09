/// Representation of a single PDF page in the organizer grid.
class PageItem {
  final int originalPageNumber;
  final int currentPosition;
  final int rotationDegrees; // 0, 90, 180, 270
  final bool isSelected;
  final String? thumbnailPath;

  const PageItem({
    required this.originalPageNumber,
    required this.currentPosition,
    this.rotationDegrees = 0,
    this.isSelected = false,
    this.thumbnailPath,
  });

  PageItem copyWith({
    int? originalPageNumber,
    int? currentPosition,
    int? rotationDegrees,
    bool? isSelected,
    String? thumbnailPath,
  }) {
    return PageItem(
      originalPageNumber: originalPageNumber ?? this.originalPageNumber,
      currentPosition: currentPosition ?? this.currentPosition,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      isSelected: isSelected ?? this.isSelected,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
