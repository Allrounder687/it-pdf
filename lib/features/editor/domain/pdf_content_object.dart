import 'dart:ui';
import 'package:flutter/material.dart';

/// Enum representing the core PDF content object types according to ISO 32000.
enum PdfContentObjectType { text, path, image, shading, form, unknown }

/// Supported vector path sub-types for creation and manipulation.
enum VectorShapeType {
  line,
  arrow,
  doubleArrow,
  rectangle,
  roundedRectangle,
  ellipse,
  circle,
  polyline,
  freeform,
}

/// Immutable 2D affine transformation matrix [a, b, c, d, e, f].
class PdfAffineMatrix {
  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  const PdfAffineMatrix({
    this.a = 1.0,
    this.b = 0.0,
    this.c = 0.0,
    this.d = 1.0,
    this.e = 0.0,
    this.f = 0.0,
  });

  static const identity = PdfAffineMatrix();

  PdfAffineMatrix copyWith({
    double? a,
    double? b,
    double? c,
    double? d,
    double? e,
    double? f,
  }) {
    return PdfAffineMatrix(
      a: a ?? this.a,
      b: b ?? this.b,
      c: c ?? this.c,
      d: d ?? this.d,
      e: e ?? this.e,
      f: f ?? this.f,
    );
  }

  Offset transformPoint(Offset point) {
    return Offset(
      a * point.dx + c * point.dy + e,
      b * point.dx + d * point.dy + f,
    );
  }
}

/// Abstract base class for all genuine PDF page content objects.
abstract class PdfContentObject {
  final String id;
  final int pageIndex; // 0-based
  final int
  objectIndex; // Index in PDFium page object list (-1 if newly created)
  final PdfContentObjectType type;
  final Rect bounds; // In PDF point coordinates (origin bottom-left, Y up)
  final PdfAffineMatrix matrix;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double opacity;
  final bool isNew;
  final bool isDeleted;

  const PdfContentObject({
    required this.id,
    required this.pageIndex,
    required this.objectIndex,
    required this.type,
    required this.bounds,
    this.matrix = const PdfAffineMatrix(),
    this.fillColor = Colors.black,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 1.0,
    this.opacity = 1.0,
    this.isNew = false,
    this.isDeleted = false,
  });

  /// Converts PDF bottom-left coordinates to Flutter top-left screen coordinates.
  Rect toScreenRect(Size pageSize, Size renderSize) {
    final scaleX = renderSize.width / pageSize.width;
    final scaleY = renderSize.height / pageSize.height;
    final screenLeft = bounds.left * scaleX;
    final screenTop = (pageSize.height - bounds.top) * scaleY;
    final screenWidth = bounds.width * scaleX;
    final screenHeight = bounds.height * scaleY;
    return Rect.fromLTWH(screenLeft, screenTop, screenWidth, screenHeight);
  }

  /// Converts Flutter top-left screen coordinates to PDF bottom-left coordinates.
  static Rect fromScreenRect(Rect screenRect, Size pageSize, Size renderSize) {
    final scaleX = pageSize.width / renderSize.width;
    final scaleY = pageSize.height / renderSize.height;
    final pdfLeft = screenRect.left * scaleX;
    final pdfWidth = screenRect.width * scaleX;
    final pdfHeight = screenRect.height * scaleY;
    final pdfTop = pageSize.height - (screenRect.top * scaleY);
    final pdfBottom = pdfTop - pdfHeight;
    return Rect.fromLTRB(pdfLeft, pdfBottom, pdfLeft + pdfWidth, pdfTop);
  }

  PdfContentObject copyWith();
}

/// Text object representing an authentic text run or line in the PDF content stream.
class PdfTextContentObject extends PdfContentObject {
  final String text;
  final String fontName;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final double characterSpacing;
  final double wordSpacing;
  final double lineSpacing;
  final TextAlign textAlign;
  final bool isEmbeddedFont;
  final bool isSubsettedFont;

  const PdfTextContentObject({
    required super.id,
    required super.pageIndex,
    required super.objectIndex,
    required super.bounds,
    required this.text,
    this.fontName = 'Helvetica',
    this.fontSize = 12.0,
    this.isBold = false,
    this.isItalic = false,
    this.characterSpacing = 0.0,
    this.wordSpacing = 0.0,
    this.lineSpacing = 1.2,
    this.textAlign = TextAlign.left,
    this.isEmbeddedFont = false,
    this.isSubsettedFont = false,
    super.matrix,
    super.fillColor,
    super.strokeColor,
    super.strokeWidth,
    super.opacity,
    super.isNew,
    super.isDeleted,
  }) : super(type: PdfContentObjectType.text);

  @override
  PdfTextContentObject copyWith({
    String? id,
    int? pageIndex,
    int? objectIndex,
    Rect? bounds,
    String? text,
    String? fontName,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    double? characterSpacing,
    double? wordSpacing,
    double? lineSpacing,
    TextAlign? textAlign,
    bool? isEmbeddedFont,
    bool? isSubsettedFont,
    PdfAffineMatrix? matrix,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    double? opacity,
    bool? isNew,
    bool? isDeleted,
  }) {
    return PdfTextContentObject(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      objectIndex: objectIndex ?? this.objectIndex,
      bounds: bounds ?? this.bounds,
      text: text ?? this.text,
      fontName: fontName ?? this.fontName,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      characterSpacing: characterSpacing ?? this.characterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      textAlign: textAlign ?? this.textAlign,
      isEmbeddedFont: isEmbeddedFont ?? this.isEmbeddedFont,
      isSubsettedFont: isSubsettedFont ?? this.isSubsettedFont,
      matrix: matrix ?? this.matrix,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isNew: isNew ?? this.isNew,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Coherent paragraph block composed of multiple grouped text lines.
class PdfParagraphBlock {
  final String id;
  final int pageIndex;
  final List<PdfTextContentObject> lines;
  final Rect bounds;
  final String fullText;
  final double averageFontSize;
  final String dominantFontName;
  final bool isBold;
  final bool isItalic;
  final Color dominantColor;
  final TextAlign alignment;

  const PdfParagraphBlock({
    required this.id,
    required this.pageIndex,
    required this.lines,
    required this.bounds,
    required this.fullText,
    required this.averageFontSize,
    required this.dominantFontName,
    this.isBold = false,
    this.isItalic = false,
    this.dominantColor = Colors.black,
    this.alignment = TextAlign.left,
  });

  PdfParagraphBlock copyWith({
    String? id,
    int? pageIndex,
    List<PdfTextContentObject>? lines,
    Rect? bounds,
    String? fullText,
    double? averageFontSize,
    String? dominantFontName,
    bool? isBold,
    bool? isItalic,
    Color? dominantColor,
    TextAlign? alignment,
  }) {
    return PdfParagraphBlock(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      lines: lines ?? this.lines,
      bounds: bounds ?? this.bounds,
      fullText: fullText ?? this.fullText,
      averageFontSize: averageFontSize ?? this.averageFontSize,
      dominantFontName: dominantFontName ?? this.dominantFontName,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      dominantColor: dominantColor ?? this.dominantColor,
      alignment: alignment ?? this.alignment,
    );
  }
}

/// Vector path or shape object in the PDF content stream.
class PdfPathContentObject extends PdfContentObject {
  final VectorShapeType shapeType;
  final List<Offset> points; // In PDF point coordinates
  final bool isClosed;
  final bool hasFill;
  final bool hasStroke;
  final double cornerRadius;
  final bool isDashed;
  final List<double>? dashPattern;

  const PdfPathContentObject({
    required super.id,
    required super.pageIndex,
    required super.objectIndex,
    required super.bounds,
    required this.shapeType,
    required this.points,
    this.isClosed = false,
    this.hasFill = false,
    this.hasStroke = true,
    this.cornerRadius = 0.0,
    this.isDashed = false,
    this.dashPattern,
    super.matrix,
    super.fillColor,
    super.strokeColor,
    super.strokeWidth,
    super.opacity,
    super.isNew,
    super.isDeleted,
  }) : super(type: PdfContentObjectType.path);

  @override
  PdfPathContentObject copyWith({
    String? id,
    int? pageIndex,
    int? objectIndex,
    Rect? bounds,
    VectorShapeType? shapeType,
    List<Offset>? points,
    bool? isClosed,
    bool? hasFill,
    bool? hasStroke,
    double? cornerRadius,
    bool? isDashed,
    List<double>? dashPattern,
    PdfAffineMatrix? matrix,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    double? opacity,
    bool? isNew,
    bool? isDeleted,
  }) {
    return PdfPathContentObject(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      objectIndex: objectIndex ?? this.objectIndex,
      bounds: bounds ?? this.bounds,
      shapeType: shapeType ?? this.shapeType,
      points: points ?? this.points,
      isClosed: isClosed ?? this.isClosed,
      hasFill: hasFill ?? this.hasFill,
      hasStroke: hasStroke ?? this.hasStroke,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      isDashed: isDashed ?? this.isDashed,
      dashPattern: dashPattern ?? this.dashPattern,
      matrix: matrix ?? this.matrix,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isNew: isNew ?? this.isNew,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Image object embedded in the PDF page content stream.
class PdfImageContentObject extends PdfContentObject {
  final String? localImagePath;
  final List<int>? rawImageBytes;
  final int pixelWidth;
  final int pixelHeight;
  final String format; // 'jpeg', 'png', etc.

  const PdfImageContentObject({
    required super.id,
    required super.pageIndex,
    required super.objectIndex,
    required super.bounds,
    this.localImagePath,
    this.rawImageBytes,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
    this.format = 'jpeg',
    super.matrix,
    super.fillColor,
    super.strokeColor,
    super.strokeWidth,
    super.opacity,
    super.isNew,
    super.isDeleted,
  }) : super(type: PdfContentObjectType.image);

  @override
  PdfImageContentObject copyWith({
    String? id,
    int? pageIndex,
    int? objectIndex,
    Rect? bounds,
    String? localImagePath,
    List<int>? rawImageBytes,
    int? pixelWidth,
    int? pixelHeight,
    String? format,
    PdfAffineMatrix? matrix,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    double? opacity,
    bool? isNew,
    bool? isDeleted,
  }) {
    return PdfImageContentObject(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      objectIndex: objectIndex ?? this.objectIndex,
      bounds: bounds ?? this.bounds,
      localImagePath: localImagePath ?? this.localImagePath,
      rawImageBytes: rawImageBytes ?? this.rawImageBytes,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      format: format ?? this.format,
      matrix: matrix ?? this.matrix,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isNew: isNew ?? this.isNew,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
