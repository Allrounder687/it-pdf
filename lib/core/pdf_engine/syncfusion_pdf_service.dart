import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../features/annotations/domain/annotation_model.dart';
import '../logging/app_logger.dart';

/// Hierarchical outline entry representing a document chapter or section bookmark.
class PdfOutlineEntry {
  final String title;
  final int targetPage; // 1-based page number
  final int level;

  const PdfOutlineEntry({
    required this.title,
    required this.targetPage,
    this.level = 0,
  });
}

/// Complete native ISO 32000 PDF manipulation service.
/// Provides lossless vector compilation, page assembly, annotation burning,
/// AcroForm inspection and AES-256 document security.
class SyncfusionPdfService {
  /// Losslessly merges multiple PDF files into a single destination file
  /// preserving vector paths, TrueType fonts, resolution and layout.
  Future<String> mergePdfs({
    required List<String> sourcePaths,
    required String outputPath,
  }) async {
    final mergedDoc = sf.PdfDocument();

    try {
      for (final path in sourcePaths) {
        final file = File(path);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final srcDoc = sf.PdfDocument(inputBytes: bytes);

        try {
          for (int i = 0; i < srcDoc.pages.count; i++) {
            final page = srcDoc.pages[i];
            final template = page.createTemplate();
            final newPage = mergedDoc.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              const Offset(0, 0),
              Size(page.size.width, page.size.height),
            );
          }
        } finally {
          srcDoc.dispose();
        }
      }

      final mergedBytes = mergedDoc.saveSync();
      await _atomicWrite(outputPath, Uint8List.fromList(mergedBytes));
      return outputPath;
    } finally {
      mergedDoc.dispose();
    }
  }

  /// Extracts selected pages with custom rotation from a source PDF into a new PDF
  /// preserving original vector fidelity and fonts.
  Future<String> extractPages({
    required String sourcePath,
    required List<int> pageNumbers, // 1-based page numbers
    Map<int, int> pageRotations = const {}, // page -> degrees (0, 90, 180, 270)
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);
    final outputDoc = sf.PdfDocument();

    try {
      for (final pageNum in pageNumbers) {
        if (pageNum < 1 || pageNum > sourceDoc.pages.count) continue;
        final srcPage = sourceDoc.pages[pageNum - 1];
        final template = srcPage.createTemplate();

        final rotationDegrees = pageRotations[pageNum] ?? 0;
        final newPage = outputDoc.pages.add();
        newPage.rotation = _mapRotation(rotationDegrees);

        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          Size(srcPage.size.width, srcPage.size.height),
        );
      }

      final outputBytes = outputDoc.saveSync();
      await _atomicWrite(outputPath, Uint8List.fromList(outputBytes));
      return outputPath;
    } finally {
      sourceDoc.dispose();
      outputDoc.dispose();
    }
  }

  /// Burns in-memory and UI annotations into the real PDF ISO 32000 stream
  /// so that Adobe Acrobat, Apple Preview, Chrome and Foxit display them.
  Future<String> burnAnnotationsToPdf({
    required String sourcePath,
    required List<Annotation> annotations,
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      for (final ann in annotations) {
        if (ann.pageNumber < 1 || ann.pageNumber > doc.pages.count) continue;
        final page = doc.pages[ann.pageNumber - 1];
        final pageSize = Size(page.size.width, page.size.height);

        final r = (ann.colorValue >> 16) & 0xFF;
        final g = (ann.colorValue >> 8) & 0xFF;
        final b = ann.colorValue & 0xFF;
        final pdfColor = sf.PdfColor(r, g, b);

        switch (ann.type) {
          case AnnotationType.highlight:
          case AnnotationType.underline:
          case AnnotationType.strikethrough:
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final markupType = ann.type == AnnotationType.underline
                  ? sf.PdfTextMarkupAnnotationType.underline
                  : (ann.type == AnnotationType.strikethrough
                      ? sf.PdfTextMarkupAnnotationType.strikethrough
                      : sf.PdfTextMarkupAnnotationType.highlight);

              final markup = sf.PdfTextMarkupAnnotation(
                rect,
                ann.textContent ?? '',
                pdfColor,
                textMarkupAnnotationType: markupType,
              );
              page.annotations.add(markup);
            }
            break;

          case AnnotationType.rectangle:
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final rectAnn = sf.PdfRectangleAnnotation(
                rect,
                ann.textContent ?? '',
                color: pdfColor,
              );
              rectAnn.border.width = ann.strokeWidth.clamp(1.0, 10.0);
              page.annotations.add(rectAnn);
            }
            break;

          case AnnotationType.circle:
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final ellipseAnn = sf.PdfEllipseAnnotation(
                rect,
                ann.textContent ?? '',
                color: pdfColor,
              );
              ellipseAnn.border.width = ann.strokeWidth.clamp(1.0, 10.0);
              page.annotations.add(ellipseAnn);
            }
            break;

          case AnnotationType.arrow:
            if (ann.points.length >= 2) {
              final p1 = ann.points.first.toOffset(pageSize);
              final p2 = ann.points.last.toOffset(pageSize);
              final lineAnn = sf.PdfLineAnnotation(
                [p1.dx.toInt(), p1.dy.toInt(), p2.dx.toInt(), p2.dy.toInt()],
                ann.textContent ?? '',
                color: pdfColor,
              );
              lineAnn.endLineStyle = sf.PdfLineEndingStyle.openArrow;
              page.annotations.add(lineAnn);
            }
            break;

          case AnnotationType.stickyNote:
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final popup = sf.PdfPopupAnnotation(
                rect,
                ann.textContent ?? 'Sticky Note',
                color: pdfColor,
              );
              page.annotations.add(popup);
            }
            break;

          case AnnotationType.ink:
            if (ann.points.length > 1) {
              for (int i = 1; i < ann.points.length; i++) {
                final pt1 = ann.points[i - 1].toOffset(pageSize);
                final pt2 = ann.points[i].toOffset(pageSize);
                page.graphics.drawLine(
                  sf.PdfPen(pdfColor, width: ann.strokeWidth),
                  Offset(pt1.dx, pt1.dy),
                  Offset(pt2.dx, pt2.dy),
                );
              }
            }
            break;

          default:
            break;
        }
      }

      final outputBytes = doc.saveSync();
      await _atomicWrite(outputPath, Uint8List.fromList(outputBytes));
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Extracts text from every page of a document for AI summarization & search.
  Future<Map<int, String>> extractDocumentText(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return {};

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final result = <int, String>{};

    try {
      final extractor = sf.PdfTextExtractor(doc);
      for (int i = 0; i < doc.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        result[i + 1] = pageText.trim();
      }
      return result;
    } finally {
      doc.dispose();
    }
  }

  /// Password-protects a PDF document using industry-standard AES-256 bit encryption.
  Future<String> protectPdfWithPassword({
    required String sourcePath,
    required String userPassword,
    required String ownerPassword,
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final security = doc.security;
      security.userPassword = userPassword;
      security.ownerPassword = ownerPassword;
      security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
      security.permissions.addAll([
        sf.PdfPermissionsFlags.print,
        sf.PdfPermissionsFlags.copyContent,
      ]);

      final outputBytes = doc.saveSync();
      await _atomicWrite(outputPath, Uint8List.fromList(outputBytes));
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Inspects interactive AcroForm fields present in a document.
  Future<List<Map<String, dynamic>>> getFormFields(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final fieldList = <Map<String, dynamic>>[];

    try {
      for (int i = 0; i < doc.form.fields.count; i++) {
        final field = doc.form.fields[i];
        String value = '';
        String typeName = 'text';

        if (field is sf.PdfTextBoxField) {
          value = field.text;
          typeName = 'text';
        } else if (field is sf.PdfCheckBoxField) {
          value = field.isChecked ? 'true' : 'false';
          typeName = 'checkbox';
        }

        fieldList.add({
          'name': field.name ?? 'field_$i',
          'type': typeName,
          'value': value,
          'pageIndex': field.page?.defaultLayerIndex ?? 0,
        });
      }
      return fieldList;
    } finally {
      doc.dispose();
    }
  }

  /// Fills form fields and optionally flattens all fields to permanently freeze values.
  Future<String> updateAndFlattenForm({
    required String sourcePath,
    required Map<String, String> fieldValues,
    required bool flatten,
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      for (int i = 0; i < doc.form.fields.count; i++) {
        final field = doc.form.fields[i];
        final name = field.name;
        if (name != null && fieldValues.containsKey(name)) {
          final newVal = fieldValues[name]!;
          if (field is sf.PdfTextBoxField) {
            field.text = newVal;
          } else if (field is sf.PdfCheckBoxField) {
            field.isChecked = newVal == 'true';
          }
        }
      }

      if (flatten) {
        doc.form.flattenAllFields();
      }

      final outputBytes = doc.saveSync();
      await _atomicWrite(outputPath, Uint8List.fromList(outputBytes));
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Extracts hierarchical document bookmarks / Table of Contents tree.
  Future<List<PdfOutlineEntry>> extractBookmarks(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final results = <PdfOutlineEntry>[];

    try {
      void parseBookmarks(sf.PdfBookmarkBase collection, int level) {
        for (int i = 0; i < collection.count; i++) {
          final bm = collection[i];
          int targetPage = 1;
          final dest = bm.destination;
          if (dest != null) {
            final pageIdx = doc.pages.indexOf(dest.page);
            if (pageIdx >= 0) {
              targetPage = pageIdx + 1;
            }
          } else if (bm.namedDestination != null) {
            final destPage = bm.namedDestination!.destination?.page;
            if (destPage != null) {
              final pageIdx = doc.pages.indexOf(destPage);
              if (pageIdx >= 0) {
                targetPage = pageIdx + 1;
              }
            }
          }
          final cleanTitle = bm.title.trim().isNotEmpty ? bm.title.trim() : 'Bookmark ${i + 1}';
          results.add(PdfOutlineEntry(
            title: cleanTitle,
            targetPage: targetPage,
            level: level,
          ));
          if (bm.count > 0) {
            parseBookmarks(bm, level + 1);
          }
        }
      }

      parseBookmarks(doc.bookmarks, 0);
      return results;
    } catch (e) {
      return [];
    } finally {
      doc.dispose();
    }
  }

  sf.PdfPageRotateAngle _mapRotation(int degrees) {
    switch (degrees) {
      case 90:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case 180:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case 270:
        return sf.PdfPageRotateAngle.rotateAngle270;
      default:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }

  Future<void> _atomicWrite(String targetPath, Uint8List bytes) async {
    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
    AppLogger.info('Atomic write completed: $targetPath (${bytes.length} bytes)');
  }
}
