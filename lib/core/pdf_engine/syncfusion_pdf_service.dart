import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../features/annotations/domain/annotation_model.dart';
import '../logging/app_logger.dart';
import '../storage/safe_document_storage.dart';

/// Hierarchical outline entry representing a document chapter or section bookmark.
class PdfOutlineEntry {
  final String title;
  final int? targetPage; // 1-based page number; null if unresolved
  final bool isResolved;
  final int level;
  final int index;
  final List<int> treePath;
  final double? destinationTop;
  final double? destinationLeft;

  const PdfOutlineEntry({
    required this.title,
    this.targetPage,
    bool? isResolved,
    this.level = 0,
    this.index = 0,
    this.treePath = const [],
    this.destinationTop,
    this.destinationLeft,
  }) : isResolved = isResolved ?? (targetPage != null && targetPage > 0);
}

/// Complete native ISO 32000 PDF manipulation service.
/// Provides lossless vector compilation, page assembly, annotation burning,
/// AcroForm inspection and AES-256 document security.
class SyncfusionPdfService {
  final SafeDocumentStorage _safeStorage;

  SyncfusionPdfService({SafeDocumentStorage? safeStorage})
    : _safeStorage = safeStorage ?? SafeDocumentStorage();

  /// Merges multiple PDF files into a single destination file.
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
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(mergedBytes),
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Merge save failed');
      }
      return outputPath;
    } finally {
      mergedDoc.dispose();
    }
  }

  /// Extracts selected pages with custom rotation from a source PDF.
  /// Uses direct page removal to preserve original page semantics,
  /// annotations, forms, and fonts for the extracted pages wherever possible.
  Future<String> extractPages({
    required String sourcePath,
    required List<int> pageNumbers, // 1-based page numbers
    Map<int, int> pageRotations = const {}, // page -> degrees (0, 90, 180, 270)
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = sf.PdfDocument(inputBytes: bytes);

    try {
      bool isMonotonic = true;
      for (int i = 1; i < pageNumbers.length; i++) {
        if (pageNumbers[i] <= pageNumbers[i - 1]) {
          isMonotonic = false;
          break;
        }
      }

      Uint8List outputBytes;
      if (isMonotonic && pageNumbers.toSet().length == pageNumbers.length) {
        // Surgical in-place removal preserves 100% of fonts, AcroForms, bookmarks
        final selectedSet = pageNumbers.toSet();
        for (int i = sourceDoc.pages.count - 1; i >= 0; i--) {
          final pageNum = i + 1;
          if (!selectedSet.contains(pageNum)) {
            sourceDoc.pages.removeAt(i);
          }
        }
        for (int i = 0; i < sourceDoc.pages.count; i++) {
          final originalPageNum = pageNumbers[i];
          final rotDegrees = pageRotations[originalPageNum] ?? 0;
          if (rotDegrees > 0) {
            sourceDoc.pages[i].rotation = _mapRotation(rotDegrees);
          }
        }
        outputBytes = Uint8List.fromList(sourceDoc.saveSync());
      } else {
        // Reordering or duplication requested: assemble into new document using templates
        final newDoc = sf.PdfDocument();
        try {
          for (int i = 0; i < pageNumbers.length; i++) {
            final pageNum = pageNumbers[i];
            if (pageNum >= 1 && pageNum <= sourceDoc.pages.count) {
              final srcPage = sourceDoc.pages[pageNum - 1];
              final template = srcPage.createTemplate();
              final section = newDoc.sections!.add();
              section.pageSettings.size = srcPage.size;
              final rotDegrees = pageRotations[pageNum] ?? 0;
              if (rotDegrees > 0) {
                section.pageSettings.rotate = _mapRotation(rotDegrees);
              }
              final newPage = section.pages.add();
              newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
            }
          }
          outputBytes = Uint8List.fromList(newDoc.saveSync());
        } finally {
          newDoc.dispose();
        }
      }

      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outputBytes,
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Extraction save failed');
      }
      return outputPath;
    } finally {
      sourceDoc.dispose();
    }
  }

  /// Losslessly deletes specific pages from a document.
  Future<String> deletePagesFromDocument({
    required String sourcePath,
    required List<int> pageNumbersToDelete, // 1-based
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final toDelete = pageNumbersToDelete.map((p) => p - 1).toSet().toList()
        ..sort();
      for (int i = toDelete.length - 1; i >= 0; i--) {
        final idx = toDelete[i];
        if (idx >= 0 && idx < doc.pages.count) {
          doc.pages.removeAt(idx);
        }
      }

      final outputBytes = doc.saveSync();
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(outputBytes),
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Delete pages save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Losslessly updates rotation on specified pages in a document.
  Future<String> rotatePagesInDocument({
    required String sourcePath,
    required Map<int, int> pageRotations, // 1-based page -> degrees
    required String outputPath,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      for (final entry in pageRotations.entries) {
        final pageIdx = entry.key - 1;
        if (pageIdx >= 0 && pageIdx < doc.pages.count) {
          doc.pages[pageIdx].rotation = _mapRotation(entry.value);
        }
      }

      final outputBytes = doc.saveSync();
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(outputBytes),
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Rotate pages save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
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
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final markup = sf.PdfTextMarkupAnnotation(
                rect,
                ann.textContent ?? '',
                pdfColor,
                textMarkupAnnotationType:
                    sf.PdfTextMarkupAnnotationType.highlight,
              );
              page.annotations.add(markup);
            } else if (ann.points.length > 1) {
              // Freeform highlighter strokes: draw smooth translucent stroke
              page.graphics.save();
              page.graphics.setTransparency(
                ann.opacity > 0 ? ann.opacity : 0.4,
              );
              final pen = sf.PdfPen(pdfColor, width: ann.strokeWidth);
              pen.lineCap = sf.PdfLineCap.round;
              pen.lineJoin = sf.PdfLineJoin.round;
              for (int i = 1; i < ann.points.length; i++) {
                final pt1 = ann.points[i - 1].toOffset(pageSize);
                final pt2 = ann.points[i].toOffset(pageSize);
                page.graphics.drawLine(
                  pen,
                  Offset(pt1.dx, pt1.dy),
                  Offset(pt2.dx, pt2.dy),
                );
              }
              page.graphics.restore();
            }
            break;

          case AnnotationType.underline:
          case AnnotationType.strikethrough:
            if (ann.rect != null) {
              final rect = ann.rect!.toRect(pageSize);
              final markupType = ann.type == AnnotationType.underline
                  ? sf.PdfTextMarkupAnnotationType.underline
                  : sf.PdfTextMarkupAnnotationType.strikethrough;

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
                border: sf.PdfAnnotationBorder(
                  ann.strokeWidth.clamp(1.0, 10.0),
                ),
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
              page.graphics.save();
              if (ann.opacity < 1.0) {
                page.graphics.setTransparency(ann.opacity);
              }
              final pen = sf.PdfPen(pdfColor, width: ann.strokeWidth);
              pen.lineCap = sf.PdfLineCap.round;
              pen.lineJoin = sf.PdfLineJoin.round;
              for (int i = 1; i < ann.points.length; i++) {
                final pt1 = ann.points[i - 1].toOffset(pageSize);
                final pt2 = ann.points[i].toOffset(pageSize);
                page.graphics.drawLine(
                  pen,
                  Offset(pt1.dx, pt1.dy),
                  Offset(pt2.dx, pt2.dy),
                );
              }
              page.graphics.restore();
            }
            break;

          default:
            break;
        }
      }

      final outputBytes = doc.saveSync();
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(outputBytes),
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Burn annotations save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Extracts text from every page of a document.
  Future<Map<int, String>> extractDocumentText(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return {};

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    final result = <int, String>{};

    try {
      final extractor = sf.PdfTextExtractor(doc);
      for (int i = 0; i < doc.pages.count; i++) {
        final pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        result[i + 1] = pageText.trim();
      }
      return result;
    } finally {
      doc.dispose();
    }
  }

  /// Extracts text from a specific single page on-demand.
  Future<String> extractSinglePageText(
    String sourcePath,
    int pageNumber,
  ) async {
    final file = File(sourcePath);
    if (!await file.exists()) return '';

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final pageIndex = pageNumber - 1;
      if (pageIndex < 0 || pageIndex >= doc.pages.count) return '';
      final extractor = sf.PdfTextExtractor(doc);
      return extractor
          .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex)
          .trim();
    } catch (_) {
      return '';
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
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(outputBytes),
        password: userPassword.isNotEmpty ? userPassword : ownerPassword,
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Password protect save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Inspects interactive AcroForm fields present in a document.
  /// Supports TextBoxes, CheckBoxes, RadioButtonLists, ComboBoxes, and ListBoxes.
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
        final List<String> options = [];

        if (field is sf.PdfTextBoxField) {
          value = field.text;
          typeName = 'text';
        } else if (field is sf.PdfCheckBoxField) {
          value = field.isChecked ? 'true' : 'false';
          typeName = 'checkbox';
        } else if (field is sf.PdfRadioButtonListField) {
          value = field.selectedValue;
          typeName = 'radio';
          for (int r = 0; r < field.items.count; r++) {
            options.add(field.items[r].value);
          }
        } else if (field is sf.PdfComboBoxField) {
          value = field.selectedValue;
          typeName = 'combobox';
          for (int c = 0; c < field.items.count; c++) {
            options.add(field.items[c].text);
          }
        } else if (field is sf.PdfListBoxField) {
          value = field.selectedValues.join(',');
          typeName = 'listbox';
          for (int l = 0; l < field.items.count; l++) {
            options.add(field.items[l].text);
          }
        }

        fieldList.add({
          'name': field.name ?? 'field_$i',
          'type': typeName,
          'value': value,
          'options': options,
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
            field.isChecked = newVal.toLowerCase() == 'true';
          } else if (field is sf.PdfRadioButtonListField) {
            field.selectedValue = newVal;
          } else if (field is sf.PdfComboBoxField) {
            field.selectedValue = newVal;
          } else if (field is sf.PdfListBoxField) {
            final split = newVal.split(',').map((s) => s.trim()).toList();
            field.selectedValues = split;
          }
        }
      }

      if (flatten) {
        doc.form.flattenAllFields();
      }

      final outputBytes = doc.saveSync();
      final result = await _safeStorage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: Uint8List.fromList(outputBytes),
      );
      if (!result.isSuccess) {
        throw StateError(result.errorMessage ?? 'Form update save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Extracts hierarchical document bookmarks / Table of Contents tree.
  /// Resolves both explicit and named destinations to prevent the page-1 fallback bug.
  /// Executes on a background isolate to keep UI frame rendering smooth.
  Future<List<PdfOutlineEntry>> extractBookmarks(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) return [];

    try {
      final bytes = await file.readAsBytes();
      return await Isolate.run(() => parseBookmarksFromBytes(bytes));
    } catch (e) {
      AppLogger.warn('Error extracting bookmarks via Syncfusion isolate: $e');
      return [];
    }
  }

  /// Synchronously parses bookmark entries from raw PDF bytes.
  static List<PdfOutlineEntry> parseBookmarksFromBytes(Uint8List bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    final results = <PdfOutlineEntry>[];
    int globalIndex = 0;

    try {
      void parseBookmarks(
        sf.PdfBookmarkBase collection,
        int level,
        List<int> parentPath,
      ) {
        for (int i = 0; i < collection.count; i++) {
          final bm = collection[i];
          final currentPath = [...parentPath, i];
          int? targetPage;
          bool isResolved = false;
          double? destTop;
          double? destLeft;

          final dest = bm.destination;
          if (dest != null) {
            final pageIdx = doc.pages.indexOf(dest.page);
            if (pageIdx >= 0 && pageIdx < doc.pages.count) {
              targetPage = pageIdx + 1;
              isResolved = true;
              destTop = dest.location.dy;
              destLeft = dest.location.dx;
            }
          } else if (bm.namedDestination != null) {
            final namedDest = bm.namedDestination!;
            sf.PdfPage? resolvedPage = namedDest.destination?.page;

            if (resolvedPage == null) {
              for (int n = 0; n < doc.namedDestinationCollection.count; n++) {
                final entry = doc.namedDestinationCollection[n];
                if (entry.title == namedDest.title &&
                    entry.destination != null) {
                  resolvedPage = entry.destination!.page;
                  destTop = entry.destination!.location.dy;
                  destLeft = entry.destination!.location.dx;
                  break;
                }
              }
            } else {
              destTop = namedDest.destination?.location.dy;
              destLeft = namedDest.destination?.location.dx;
            }

            if (resolvedPage != null) {
              final pageIdx = doc.pages.indexOf(resolvedPage);
              if (pageIdx >= 0 && pageIdx < doc.pages.count) {
                targetPage = pageIdx + 1;
                isResolved = true;
              }
            }
          }

          // Fallback: match by title against document named destinations if destination was indirect
          if (!isResolved) {
            for (int n = 0; n < doc.namedDestinationCollection.count; n++) {
              final entry = doc.namedDestinationCollection[n];
              if (entry.title.trim() == bm.title.trim() &&
                  entry.destination != null) {
                final resolvedPage = entry.destination!.page;
                final pageIdx = doc.pages.indexOf(resolvedPage);
                if (pageIdx >= 0 && pageIdx < doc.pages.count) {
                  targetPage = pageIdx + 1;
                  isResolved = true;
                  destTop = entry.destination!.location.dy;
                  destLeft = entry.destination!.location.dx;
                  break;
                }
              }
            }
          }

          // Bound validation: targetPage must fall strictly within document bounds
          if (targetPage != null &&
              (targetPage < 1 || targetPage > doc.pages.count)) {
            targetPage = null;
            isResolved = false;
          }

          final cleanTitle = bm.title.trim().isNotEmpty
              ? bm.title.trim()
              : 'Bookmark ${globalIndex + 1}';
          results.add(
            PdfOutlineEntry(
              title: cleanTitle,
              targetPage: targetPage,
              isResolved: isResolved,
              level: level,
              index: globalIndex++,
              treePath: currentPath,
              destinationTop: destTop,
              destinationLeft: destLeft,
            ),
          );
          if (bm.count > 0) {
            parseBookmarks(bm, level + 1, currentPath);
          }
        }
      }

      parseBookmarks(doc.bookmarks, 0, []);
      return results;
    } catch (e) {
      AppLogger.warn('Error inside parseBookmarksFromBytes: $e');
      return results;
    } finally {
      doc.dispose();
    }
  }

  sf.PdfPageRotateAngle _mapRotation(int degrees) {
    switch (degrees % 360) {
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
}
