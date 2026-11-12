import 'dart:ui';
import 'pdf_content_object.dart';

/// Abstract class for atomic PDF content edit operations.
abstract class PdfEditOperation {
  final String objectId;
  final int pageIndex;
  final DateTime timestamp;

  PdfEditOperation({
    required this.objectId,
    required this.pageIndex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Applies this operation forward.
  PdfContentObject apply(PdfContentObject target);

  /// Inverts this operation for undo.
  PdfContentObject revert(PdfContentObject target);

  /// Human-readable description for UI tooltips and undo/redo history.
  String get description;
}

/// Operation modifying the textual content of a text object.
class ModifyTextOperation extends PdfEditOperation {
  final String oldText;
  final String newText;
  final Rect? oldBounds;
  final Rect? newBounds;

  ModifyTextOperation({
    required super.objectId,
    required super.pageIndex,
    required this.oldText,
    required this.newText,
    this.oldBounds,
    this.newBounds,
  });

  @override
  PdfContentObject apply(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(text: newText, bounds: newBounds ?? target.bounds);
    }
    return target;
  }

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(text: oldText, bounds: oldBounds ?? target.bounds);
    }
    return target;
  }

  @override
  String get description => 'Edit Text "$newText"';
}

/// Operation moving an object to a new PDF position.
class MoveObjectOperation extends PdfEditOperation {
  final Rect oldBounds;
  final Rect newBounds;
  final double deltaX;
  final double deltaY;

  MoveObjectOperation({
    required super.objectId,
    required super.pageIndex,
    required this.oldBounds,
    required this.newBounds,
    required this.deltaX,
    required this.deltaY,
  });

  @override
  PdfContentObject apply(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(bounds: newBounds);
    } else if (target is PdfPathContentObject) {
      final shiftedPoints = target.points
          .map((pt) => Offset(pt.dx + deltaX, pt.dy + deltaY))
          .toList();
      return target.copyWith(bounds: newBounds, points: shiftedPoints);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(bounds: newBounds);
    }
    return target;
  }

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(bounds: oldBounds);
    } else if (target is PdfPathContentObject) {
      final shiftedPoints = target.points
          .map((pt) => Offset(pt.dx - deltaX, pt.dy - deltaY))
          .toList();
      return target.copyWith(bounds: oldBounds, points: shiftedPoints);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(bounds: oldBounds);
    }
    return target;
  }

  @override
  String get description => 'Move Object';
}

/// Operation resizing an object.
class ResizeObjectOperation extends PdfEditOperation {
  final Rect oldBounds;
  final Rect newBounds;

  ResizeObjectOperation({
    required super.objectId,
    required super.pageIndex,
    required this.oldBounds,
    required this.newBounds,
  });

  @override
  PdfContentObject apply(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      final scaleFactor = oldBounds.height > 0
          ? newBounds.height / oldBounds.height
          : 1.0;
      return target.copyWith(
        bounds: newBounds,
        fontSize: target.fontSize * scaleFactor,
      );
    } else if (target is PdfPathContentObject) {
      return target.copyWith(bounds: newBounds);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(bounds: newBounds);
    }
    return target;
  }

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      final scaleFactor = newBounds.height > 0
          ? oldBounds.height / newBounds.height
          : 1.0;
      return target.copyWith(
        bounds: oldBounds,
        fontSize: target.fontSize * scaleFactor,
      );
    } else if (target is PdfPathContentObject) {
      return target.copyWith(bounds: oldBounds);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(bounds: oldBounds);
    }
    return target;
  }

  @override
  String get description => 'Resize Object';
}

/// Operation updating styling (colors, fonts, stroke width, opacity).
class StyleObjectOperation extends PdfEditOperation {
  final Color? oldFillColor;
  final Color? newFillColor;
  final Color? oldStrokeColor;
  final Color? newStrokeColor;
  final double? oldStrokeWidth;
  final double? newStrokeWidth;
  final String? oldFontName;
  final String? newFontName;
  final double? oldFontSize;
  final double? newFontSize;
  final bool? oldBold;
  final bool? newBold;
  final bool? oldItalic;
  final bool? newItalic;

  StyleObjectOperation({
    required super.objectId,
    required super.pageIndex,
    this.oldFillColor,
    this.newFillColor,
    this.oldStrokeColor,
    this.newStrokeColor,
    this.oldStrokeWidth,
    this.newStrokeWidth,
    this.oldFontName,
    this.newFontName,
    this.oldFontSize,
    this.newFontSize,
    this.oldBold,
    this.newBold,
    this.oldItalic,
    this.newItalic,
  });

  @override
  PdfContentObject apply(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(
        fillColor: newFillColor ?? target.fillColor,
        fontName: newFontName ?? target.fontName,
        fontSize: newFontSize ?? target.fontSize,
        isBold: newBold ?? target.isBold,
        isItalic: newItalic ?? target.isItalic,
      );
    } else if (target is PdfPathContentObject) {
      return target.copyWith(
        fillColor: newFillColor ?? target.fillColor,
        strokeColor: newStrokeColor ?? target.strokeColor,
        strokeWidth: newStrokeWidth ?? target.strokeWidth,
      );
    }
    return target;
  }

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(
        fillColor: oldFillColor ?? target.fillColor,
        fontName: oldFontName ?? target.fontName,
        fontSize: oldFontSize ?? target.fontSize,
        isBold: oldBold ?? target.isBold,
        isItalic: oldItalic ?? target.isItalic,
      );
    } else if (target is PdfPathContentObject) {
      return target.copyWith(
        fillColor: oldFillColor ?? target.fillColor,
        strokeColor: oldStrokeColor ?? target.strokeColor,
        strokeWidth: oldStrokeWidth ?? target.strokeWidth,
      );
    }
    return target;
  }

  @override
  String get description => 'Change Style';
}

/// Operation inserting a new content object into the page.
class InsertObjectOperation extends PdfEditOperation {
  final PdfContentObject object;

  InsertObjectOperation({required this.object})
    : super(objectId: object.id, pageIndex: object.pageIndex);

  @override
  PdfContentObject apply(PdfContentObject target) => object;

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(isDeleted: true);
    } else if (target is PdfPathContentObject) {
      return target.copyWith(isDeleted: true);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(isDeleted: true);
    }
    return target;
  }

  @override
  String get description => 'Insert ${object.type.name.toUpperCase()}';
}

/// Operation deleting an existing object.
class DeleteObjectOperation extends PdfEditOperation {
  final PdfContentObject deletedObject;

  DeleteObjectOperation({required this.deletedObject})
    : super(objectId: deletedObject.id, pageIndex: deletedObject.pageIndex);

  @override
  PdfContentObject apply(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(isDeleted: true);
    } else if (target is PdfPathContentObject) {
      return target.copyWith(isDeleted: true);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(isDeleted: true);
    }
    return target;
  }

  @override
  PdfContentObject revert(PdfContentObject target) {
    if (target is PdfTextContentObject) {
      return target.copyWith(isDeleted: false);
    } else if (target is PdfPathContentObject) {
      return target.copyWith(isDeleted: false);
    } else if (target is PdfImageContentObject) {
      return target.copyWith(isDeleted: false);
    }
    return target;
  }

  @override
  String get description => 'Delete Object';
}

/// Grouped transaction containing one or more atomic operations.
class PdfEditTransaction {
  final String id;
  final String name;
  final List<PdfEditOperation> operations;
  final DateTime timestamp;

  PdfEditTransaction({
    required this.id,
    required this.name,
    required this.operations,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
