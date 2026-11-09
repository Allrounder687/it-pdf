import 'dart:convert';
import 'package:flutter/material.dart';

/// Supported types of vector PDF annotations.
enum AnnotationType {
  ink,
  highlight,
  underline,
  strikethrough,
  rectangle,
  circle,
  arrow,
  stickyNote,
  textCallout,
}

/// Active tool in the annotation toolbar.
enum AnnotationTool {
  none,
  pen,
  marker,
  highlighter,
  rectangle,
  circle,
  arrow,
  stickyNote,
  eraser,
}

/// Normalized coordinate point (0.0 to 1.0) relative to page dimensions.
class NormalizedPoint {
  final double x;
  final double y;

  const NormalizedPoint(this.x, this.y);

  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  factory NormalizedPoint.fromMap(Map<String, dynamic> map) {
    return NormalizedPoint(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
    );
  }

  Offset toOffset(Size pageSize) => Offset(x * pageSize.width, y * pageSize.height);

  static NormalizedPoint fromOffset(Offset offset, Size pageSize) {
    return NormalizedPoint(
      (offset.dx / pageSize.width).clamp(0.0, 1.0),
      (offset.dy / pageSize.height).clamp(0.0, 1.0),
    );
  }
}

/// Normalized bounding rectangle relative to page dimensions.
class NormalizedRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => (right - left).abs();
  double get height => (bottom - top).abs();

  Map<String, dynamic> toMap() => {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  factory NormalizedRect.fromMap(Map<String, dynamic> map) {
    return NormalizedRect(
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      right: (map['right'] as num).toDouble(),
      bottom: (map['bottom'] as num).toDouble(),
    );
  }

  Rect toRect(Size pageSize) {
    return Rect.fromLTRB(
      left * pageSize.width,
      top * pageSize.height,
      right * pageSize.width,
      bottom * pageSize.height,
    );
  }

  static NormalizedRect fromRect(Rect rect, Size pageSize) {
    return NormalizedRect(
      left: (rect.left / pageSize.width).clamp(0.0, 1.0),
      top: (rect.top / pageSize.height).clamp(0.0, 1.0),
      right: (rect.right / pageSize.width).clamp(0.0, 1.0),
      bottom: (rect.bottom / pageSize.height).clamp(0.0, 1.0),
    );
  }
}

/// Complete representation of an individual persistent PDF annotation.
class Annotation {
  final String id;
  final String documentId;
  final int pageNumber;
  final AnnotationType type;
  final int colorValue;
  final double strokeWidth;
  final double opacity;
  final List<NormalizedPoint> points;
  final NormalizedRect? rect;
  final String? textContent;
  final DateTime createdAt;

  const Annotation({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.type,
    required this.colorValue,
    this.strokeWidth = 2.0,
    this.opacity = 1.0,
    this.points = const [],
    this.rect,
    this.textContent,
    required this.createdAt,
  });

  Color get color => Color(colorValue).withValues(alpha: opacity);

  Annotation copyWith({
    String? id,
    String? documentId,
    int? pageNumber,
    AnnotationType? type,
    int? colorValue,
    double? strokeWidth,
    double? opacity,
    List<NormalizedPoint>? points,
    NormalizedRect? rect,
    String? textContent,
    DateTime? createdAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
      rect: rect ?? this.rect,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'pageNumber': pageNumber,
      'type': type.name,
      'colorValue': colorValue,
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'points': points.map((p) => p.toMap()).toList(),
      'rect': rect?.toMap(),
      'textContent': textContent,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Annotation.fromMap(Map<String, dynamic> map) {
    return Annotation(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      pageNumber: (map['pageNumber'] as num).toInt(),
      type: AnnotationType.values.byName(map['type'] as String),
      colorValue: (map['colorValue'] as num).toInt(),
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
      points: (map['points'] as List? ?? const [])
          .map((p) => NormalizedPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      rect: map['rect'] != null
          ? NormalizedRect.fromMap(map['rect'] as Map<String, dynamic>)
          : null,
      textContent: map['textContent'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Annotation.fromJson(String source) =>
      Annotation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
