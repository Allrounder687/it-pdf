import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../../core/storage/safe_document_storage.dart';
import '../domain/pdf_content_object.dart';
import '../domain/pdf_edit_transaction.dart';
import 'pdf_content_editing_backend.dart';
import 'pdf_font_manager.dart';

// Top-level buffer for FPDF_FILEWRITE callback
BytesBuilder _globalFileWriteBuffer = BytesBuilder();

int _globalWriteBlockCallback(
  Pointer<FPDF_FILEWRITE> pThis,
  Pointer<Void> pData,
  int size,
) {
  try {
    final bytes = pData.cast<Uint8>().asTypedList(size);
    _globalFileWriteBuffer.add(bytes);
    return 1;
  } catch (_) {
    return 0;
  }
}

/// Battle-tested, native PDFium FFI backend for genuine PDF content editing.
class PdfiumEditingBackend implements PdfContentEditingBackend {
  final SafeDocumentStorage _safeStorage;
  static bool _initialized = false;
  static final Object _lock = Object();

  PdfiumEditingBackend({SafeDocumentStorage? safeStorage})
    : _safeStorage = safeStorage ?? SafeDocumentStorage();

  void _ensureInitialized(PDFium pdfium) {
    if (!_initialized) {
      synchronizedInit(pdfium);
    }
  }

  static void synchronizedInit(PDFium pdfium) {
    synchronized(_lock, () {
      if (!_initialized) {
        pdfium.FPDF_InitLibrary();
        _initialized = true;
      }
    });
  }

  static void synchronized(Object lock, void Function() block) {
    block();
  }

  @override
  Future<List<PdfContentObject>> extractPageObjects({
    required String filePath,
    required int pageIndex,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final pdfium = getPdfium();
    _ensureInitialized(pdfium);

    // Also extract text lines via Syncfusion for enriched font styles (bold/italic)
    final sfLines = await _extractSyncfusionLines(filePath, pageIndex);

    final pathUtf8 = filePath.toNativeUtf8();
    final doc = pdfium.FPDF_LoadDocument(pathUtf8.cast(), nullptr);
    calloc.free(pathUtf8);

    if (doc.address == 0) return [];

    final results = <PdfContentObject>[];

    try {
      final page = pdfium.FPDF_LoadPage(doc, pageIndex);
      if (page.address == 0) return [];

      final textPage = pdfium.FPDFText_LoadPage(page);

      final objCount = pdfium.FPDFPage_CountObjects(page);

      final pLeft = calloc<Float>();
      final pBottom = calloc<Float>();
      final pRight = calloc<Float>();
      final pTop = calloc<Float>();
      final pFontSize = calloc<Float>();
      final pStrokeWidth = calloc<Float>();
      final pR = calloc<UnsignedInt>();
      final pG = calloc<UnsignedInt>();
      final pB = calloc<UnsignedInt>();
      final pA = calloc<UnsignedInt>();
      final pMatrix = calloc<FS_MATRIX>();

      for (var i = 0; i < objCount; i++) {
        final obj = pdfium.FPDFPage_GetObject(page, i);
        if (obj.address == 0) continue;

        final typeCode = pdfium.FPDFPageObj_GetType(obj);
        final boundsOk = pdfium.FPDFPageObj_GetBounds(
          obj,
          pLeft,
          pBottom,
          pRight,
          pTop,
        );
        if (boundsOk == 0) continue;

        final bounds = Rect.fromLTRB(
          pLeft.value.toDouble(),
          pBottom.value.toDouble(),
          pRight.value.toDouble(),
          pTop.value.toDouble(),
        );

        // Fill color
        Color fillColor = Colors.black;
        if (pdfium.FPDFPageObj_GetFillColor(obj, pR, pG, pB, pA) == 1) {
          fillColor = Color.fromARGB(
            pA.value.clamp(0, 255),
            pR.value.clamp(0, 255),
            pG.value.clamp(0, 255),
            pB.value.clamp(0, 255),
          );
        }

        // Stroke color & width
        Color strokeColor = Colors.transparent;
        if (pdfium.FPDFPageObj_GetStrokeColor(obj, pR, pG, pB, pA) == 1) {
          strokeColor = Color.fromARGB(
            pA.value.clamp(0, 255),
            pR.value.clamp(0, 255),
            pG.value.clamp(0, 255),
            pB.value.clamp(0, 255),
          );
        }
        double strokeWidth = 1.0;
        if (pdfium.FPDFPageObj_GetStrokeWidth(obj, pStrokeWidth) == 1) {
          strokeWidth = pStrokeWidth.value.toDouble();
        }

        // Matrix
        PdfAffineMatrix matrix = const PdfAffineMatrix();
        if (pdfium.FPDFPageObj_GetMatrix(obj, pMatrix) == 1) {
          matrix = PdfAffineMatrix(
            a: pMatrix.ref.a,
            b: pMatrix.ref.b,
            c: pMatrix.ref.c,
            d: pMatrix.ref.d,
            e: pMatrix.ref.e,
            f: pMatrix.ref.f,
          );
        }

        if (typeCode == 1) {
          // FPDF_PAGEOBJ_TEXT
          final buf = calloc<Uint16>(512);
          final charCount = pdfium.FPDFTextObj_GetText(
            obj,
            textPage,
            buf.cast(),
            512,
          );
          String extractedText = '';
          if (charCount > 0) {
            final units = <int>[];
            for (var c = 0; c < charCount; c++) {
              final code = buf[c];
              if (code == 0) break;
              units.add(code);
            }
            extractedText = String.fromCharCodes(units).trim();
          }
          calloc.free(buf);

          double fontSize = 12.0;
          if (pdfium.FPDFTextObj_GetFontSize(obj, pFontSize) == 1) {
            fontSize = pFontSize.value.toDouble();
          }

          // Correlate with Syncfusion for font name, bold, italic
          String fontName = 'Helvetica';
          bool isBold = false;
          bool isItalic = false;

          final matchedSf = _findMatchingSfLine(sfLines, bounds, extractedText);
          if (matchedSf != null) {
            fontName = matchedSf.fontName;
            isBold = matchedSf.fontStyle.contains(sf.PdfFontStyle.bold);
            isItalic = matchedSf.fontStyle.contains(sf.PdfFontStyle.italic);
          }

          results.add(
            PdfTextContentObject(
              id: 'text_${pageIndex}_$i',
              pageIndex: pageIndex,
              objectIndex: i,
              bounds: bounds,
              text: extractedText,
              fontName: fontName,
              fontSize: fontSize > 0 ? fontSize : 12.0,
              isBold: isBold,
              isItalic: isItalic,
              fillColor: fillColor,
              strokeColor: strokeColor,
              strokeWidth: strokeWidth > 0 ? strokeWidth : 1.0,
              matrix: matrix,
            ),
          );
        } else if (typeCode == 2) {
          // FPDF_PAGEOBJ_PATH
          final shapeType = bounds.height <= 3 || bounds.width <= 3
              ? VectorShapeType.line
              : VectorShapeType.rectangle;

          results.add(
            PdfPathContentObject(
              id: 'path_${pageIndex}_$i',
              pageIndex: pageIndex,
              objectIndex: i,
              bounds: bounds,
              shapeType: shapeType,
              points: [
                Offset(bounds.left, bounds.bottom),
                Offset(bounds.right, bounds.top),
              ],
              hasFill: fillColor.alpha > 0,
              hasStroke: strokeColor.alpha > 0 || strokeWidth > 0,
              fillColor: fillColor,
              strokeColor: strokeColor.alpha > 0 ? strokeColor : fillColor,
              strokeWidth: strokeWidth > 0 ? strokeWidth : 1.0,
              matrix: matrix,
            ),
          );
        } else if (typeCode == 3) {
          // FPDF_PAGEOBJ_IMAGE
          results.add(
            PdfImageContentObject(
              id: 'img_${pageIndex}_$i',
              pageIndex: pageIndex,
              objectIndex: i,
              bounds: bounds,
              matrix: matrix,
            ),
          );
        }
      }

      calloc.free(pLeft);
      calloc.free(pBottom);
      calloc.free(pRight);
      calloc.free(pTop);
      calloc.free(pFontSize);
      calloc.free(pStrokeWidth);
      calloc.free(pR);
      calloc.free(pG);
      calloc.free(pB);
      calloc.free(pA);
      calloc.free(pMatrix);

      pdfium.FPDFText_ClosePage(textPage);
      pdfium.FPDF_ClosePage(page);
    } finally {
      pdfium.FPDF_CloseDocument(doc);
    }

    return results;
  }

  @override
  Future<List<PdfParagraphBlock>> extractParagraphs({
    required String filePath,
    required int pageIndex,
  }) async {
    final objects = await extractPageObjects(
      filePath: filePath,
      pageIndex: pageIndex,
    );

    final textObjs = objects.whereType<PdfTextContentObject>().toList();
    if (textObjs.isEmpty) return [];

    // Sort by vertical position (top to bottom), then horizontal (left to right)
    textObjs.sort((a, b) {
      final yComp = b.bounds.top.compareTo(a.bounds.top);
      if (yComp.abs() > 4) return yComp;
      return a.bounds.left.compareTo(b.bounds.left);
    });

    final paragraphs = <PdfParagraphBlock>[];
    final currentGroup = <PdfTextContentObject>[];

    for (var i = 0; i < textObjs.length; i++) {
      final current = textObjs[i];
      if (currentGroup.isEmpty) {
        currentGroup.add(current);
        continue;
      }

      final prev = currentGroup.last;
      final verticalDistance = (prev.bounds.bottom - current.bounds.top).abs();
      final lineSpacingThreshold = prev.fontSize * 1.8;
      final horizontalDistance = (current.bounds.left - prev.bounds.left).abs();

      // Check if lines are part of the same paragraph flow
      if (verticalDistance <= lineSpacingThreshold &&
          horizontalDistance < 40 &&
          (prev.fontSize - current.fontSize).abs() < 3) {
        currentGroup.add(current);
      } else {
        paragraphs.add(_buildParagraphBlock(currentGroup, pageIndex));
        currentGroup.clear();
        currentGroup.add(current);
      }
    }

    if (currentGroup.isNotEmpty) {
      paragraphs.add(_buildParagraphBlock(currentGroup, pageIndex));
    }

    return paragraphs;
  }

  PdfParagraphBlock _buildParagraphBlock(
    List<PdfTextContentObject> lines,
    int pageIndex,
  ) {
    double minLeft = double.infinity;
    double minBottom = double.infinity;
    double maxRight = -double.infinity;
    double maxTop = -double.infinity;
    final sb = StringBuffer();

    double totalFontSize = 0.0;
    for (var l in lines) {
      if (l.bounds.left < minLeft) minLeft = l.bounds.left;
      if (l.bounds.bottom < minBottom) minBottom = l.bounds.bottom;
      if (l.bounds.right > maxRight) maxRight = l.bounds.right;
      if (l.bounds.top > maxTop) maxTop = l.bounds.top;

      if (sb.isNotEmpty) sb.write(' ');
      sb.write(l.text);
      totalFontSize += l.fontSize;
    }

    final avgFontSize = totalFontSize / lines.length;
    final first = lines.first;

    return PdfParagraphBlock(
      id: 'para_${pageIndex}_${first.objectIndex}',
      pageIndex: pageIndex,
      lines: List.unmodifiable(lines),
      bounds: Rect.fromLTRB(minLeft, minBottom, maxRight, maxTop),
      fullText: sb.toString(),
      averageFontSize: avgFontSize,
      dominantFontName: first.fontName,
      isBold: first.isBold,
      isItalic: first.isItalic,
      dominantColor: first.fillColor,
    );
  }

  @override
  Future<String> commitModifications({
    required String sourcePath,
    required String targetPath,
    required Map<int, List<PdfContentObject>> modifiedPagesObjects,
    required List<PdfEditOperation> operations,
  }) async {
    final pdfium = getPdfium();
    _ensureInitialized(pdfium);

    final pathUtf8 = sourcePath.toNativeUtf8();
    final doc = pdfium.FPDF_LoadDocument(pathUtf8.cast(), nullptr);
    calloc.free(pathUtf8);

    if (doc.address == 0) {
      throw Exception('Failed to load document for editing: $sourcePath');
    }

    try {
      // Process each modified page
      for (final entry in modifiedPagesObjects.entries) {
        final pageIndex = entry.key;
        final pageObjects = entry.value;

        final page = pdfium.FPDF_LoadPage(doc, pageIndex);
        if (page.address == 0) continue;

        // Process deletions first
        for (final obj in pageObjects.where((o) => o.isDeleted)) {
          if (obj.objectIndex >= 0) {
            final pageObj = pdfium.FPDFPage_GetObject(page, obj.objectIndex);
            if (pageObj.address != 0) {
              pdfium.FPDFPage_RemoveObject(page, pageObj);
              pdfium.FPDFPageObj_Destroy(pageObj);
            }
          }
        }

        // Process modified existing objects and new insertions
        for (final obj in pageObjects.where((o) => !o.isDeleted)) {
          if (obj is PdfTextContentObject) {
            _applyTextObject(pdfium, doc, page, obj);
          } else if (obj is PdfPathContentObject) {
            _applyPathObject(pdfium, doc, page, obj);
          } else if (obj is PdfImageContentObject) {
            _applyImageObject(pdfium, doc, page, obj);
          }
        }

        // Regenerate page content stream
        final genOk = pdfium.FPDFPage_GenerateContent(page);
        if (genOk == 0) {
          throw Exception(
            'Failed to generate page content for page $pageIndex',
          );
        }

        pdfium.FPDF_ClosePage(page);
      }

      // Save document atomically using FPDF_SaveAsCopy
      _globalFileWriteBuffer.clear();
      final fw = calloc<FPDF_FILEWRITE>();
      fw.ref.version = 1;
      fw.ref.WriteBlock =
          Pointer.fromFunction<
            Int Function(Pointer<FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
          >(_globalWriteBlockCallback, 0);

      final saveRes = pdfium.FPDF_SaveAsCopy(doc, fw, 0);
      calloc.free(fw);

      if (saveRes == 0) {
        throw Exception('FPDF_SaveAsCopy failed to produce output.');
      }

      final savedBytes = _globalFileWriteBuffer.takeBytes();
      if (savedBytes.isEmpty) {
        throw Exception('Saved document bytes were empty.');
      }

      // Commit to storage safely
      final saveResult = await _safeStorage.transactionalSaveBytes(
        targetPath: targetPath,
        bytes: savedBytes,
      );
      if (!saveResult.isSuccess) {
        throw Exception('Failed to save document: ${saveResult.errorMessage}');
      }
      final resultPath = saveResult.path;

      // Verify that output can be reopened
      final isValid = await verifyPdfIntegrity(filePath: resultPath);
      if (!isValid) {
        throw Exception('Generated PDF failed verification check.');
      }

      return resultPath;
    } finally {
      pdfium.FPDF_CloseDocument(doc);
    }
  }

  void _applyTextObject(
    PDFium pdfium,
    FPDF_DOCUMENT doc,
    FPDF_PAGE page,
    PdfTextContentObject textObj,
  ) {
    if (textObj.isNew || textObj.objectIndex < 0) {
      // Insert new native text object
      final fontStandardName = PdfFontManager.resolveStandardFontName(
        family: textObj.fontName,
        isBold: textObj.isBold,
        isItalic: textObj.isItalic,
      );
      final fontNameUtf8 = fontStandardName.toNativeUtf8();
      final font = pdfium.FPDFText_LoadStandardFont(doc, fontNameUtf8.cast());
      calloc.free(fontNameUtf8);

      final newObj = pdfium.FPDFPageObj_CreateTextObj(
        doc,
        font,
        textObj.fontSize,
      );

      // Set UTF-16LE text
      final textUnits = textObj.text.codeUnits;
      final textPtr = calloc<Uint16>(textUnits.length + 1);
      for (var i = 0; i < textUnits.length; i++) {
        textPtr[i] = textUnits[i];
      }
      textPtr[textUnits.length] = 0;
      pdfium.FPDFText_SetText(newObj, textPtr.cast());
      calloc.free(textPtr);

      // Set Fill Color
      pdfium.FPDFPageObj_SetFillColor(
        newObj,
        textObj.fillColor.red,
        textObj.fillColor.green,
        textObj.fillColor.blue,
        textObj.fillColor.alpha,
      );

      // Position text
      pdfium.FPDFPageObj_Transform(
        newObj,
        1.0,
        0.0,
        0.0,
        1.0,
        textObj.bounds.left,
        textObj.bounds.bottom,
      );

      pdfium.FPDFPage_InsertObject(page, newObj);
    } else {
      // Modify existing text object
      final pageObj = pdfium.FPDFPage_GetObject(page, textObj.objectIndex);
      if (pageObj.address != 0) {
        // Update text content
        final textUnits = textObj.text.codeUnits;
        final textPtr = calloc<Uint16>(textUnits.length + 1);
        for (var i = 0; i < textUnits.length; i++) {
          textPtr[i] = textUnits[i];
        }
        textPtr[textUnits.length] = 0;
        pdfium.FPDFText_SetText(pageObj, textPtr.cast());
        calloc.free(textPtr);

        // Update Fill Color
        pdfium.FPDFPageObj_SetFillColor(
          pageObj,
          textObj.fillColor.red,
          textObj.fillColor.green,
          textObj.fillColor.blue,
          textObj.fillColor.alpha,
        );
      }
    }
  }

  void _applyPathObject(
    PDFium pdfium,
    FPDF_DOCUMENT doc,
    FPDF_PAGE page,
    PdfPathContentObject pathObj,
  ) {
    if (pathObj.isNew || pathObj.objectIndex < 0) {
      FPDF_PAGEOBJECT newPath;
      if (pathObj.shapeType == VectorShapeType.rectangle) {
        newPath = pdfium.FPDFPageObj_CreateNewRect(
          pathObj.bounds.left,
          pathObj.bounds.bottom,
          pathObj.bounds.width,
          pathObj.bounds.height,
        );
      } else {
        // Draw path segments
        final startX = pathObj.points.isNotEmpty
            ? pathObj.points.first.dx
            : pathObj.bounds.left;
        final startY = pathObj.points.isNotEmpty
            ? pathObj.points.first.dy
            : pathObj.bounds.bottom;
        newPath = pdfium.FPDFPageObj_CreateNewPath(startX, startY);

        for (var i = 1; i < pathObj.points.length; i++) {
          final pt = pathObj.points[i];
          pdfium.FPDFPath_LineTo(newPath, pt.dx, pt.dy);
        }

        if (pathObj.isClosed) {
          pdfium.FPDFPath_Close(newPath);
        }
      }

      final fillMode = pathObj.hasFill ? 1 : 0;
      final stroke = pathObj.hasStroke ? 1 : 0;
      pdfium.FPDFPath_SetDrawMode(newPath, fillMode, stroke);

      if (pathObj.hasStroke) {
        pdfium.FPDFPageObj_SetStrokeColor(
          newPath,
          pathObj.strokeColor.red,
          pathObj.strokeColor.green,
          pathObj.strokeColor.blue,
          pathObj.strokeColor.alpha,
        );
        pdfium.FPDFPageObj_SetStrokeWidth(newPath, pathObj.strokeWidth);
      }

      if (pathObj.hasFill) {
        pdfium.FPDFPageObj_SetFillColor(
          newPath,
          pathObj.fillColor.red,
          pathObj.fillColor.green,
          pathObj.fillColor.blue,
          pathObj.fillColor.alpha,
        );
      }

      pdfium.FPDFPage_InsertObject(page, newPath);
    }
  }

  void _applyImageObject(
    PDFium pdfium,
    FPDF_DOCUMENT doc,
    FPDF_PAGE page,
    PdfImageContentObject imgObj,
  ) {
    if ((imgObj.isNew || imgObj.objectIndex < 0) &&
        imgObj.localImagePath != null) {
      final newImg = pdfium.FPDFPageObj_NewImageObj(doc);

      final pathUtf8 = imgObj.localImagePath!.toNativeUtf8();
      pdfium.FPDFImageObj_LoadJpegFile(nullptr, 0, newImg, pathUtf8.cast());
      calloc.free(pathUtf8);

      pdfium.FPDFImageObj_SetMatrix(
        newImg,
        imgObj.bounds.width,
        0.0,
        0.0,
        imgObj.bounds.height,
        imgObj.bounds.left,
        imgObj.bounds.bottom,
      );

      pdfium.FPDFPage_InsertObject(page, newImg);
    }
  }

  @override
  Future<bool> verifyPdfIntegrity({required String filePath}) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final size = await file.length();
    if (size < 100) return false;

    final pdfium = getPdfium();
    _ensureInitialized(pdfium);

    final pathUtf8 = filePath.toNativeUtf8();
    final doc = pdfium.FPDF_LoadDocument(pathUtf8.cast(), nullptr);
    calloc.free(pathUtf8);

    if (doc.address == 0) return false;

    final pageCount = pdfium.FPDF_GetPageCount(doc);
    pdfium.FPDF_CloseDocument(doc);
    return pageCount > 0;
  }

  @override
  Future<bool> hasDigitalSignatures({required String filePath}) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final pdfium = getPdfium();
    _ensureInitialized(pdfium);

    final pathUtf8 = filePath.toNativeUtf8();
    final doc = pdfium.FPDF_LoadDocument(pathUtf8.cast(), nullptr);
    calloc.free(pathUtf8);

    if (doc.address == 0) return false;

    final sigCount = pdfium.FPDF_GetSignatureCount(doc);
    pdfium.FPDF_CloseDocument(doc);
    return sigCount > 0;
  }

  Future<List<sf.TextLine>> _extractSyncfusionLines(
    String filePath,
    int pageIndex,
  ) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      if (pageIndex < 0 || pageIndex >= doc.pages.count) {
        doc.dispose();
        return [];
      }
      final extractor = sf.PdfTextExtractor(doc);
      final lines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      doc.dispose();
      return lines;
    } catch (_) {
      return [];
    }
  }

  sf.TextLine? _findMatchingSfLine(
    List<sf.TextLine> sfLines,
    Rect bounds,
    String text,
  ) {
    if (sfLines.isEmpty || text.isEmpty) return null;
    for (final line in sfLines) {
      if (line.text.contains(text) || text.contains(line.text.trim())) {
        return line;
      }
    }
    return null;
  }
}
