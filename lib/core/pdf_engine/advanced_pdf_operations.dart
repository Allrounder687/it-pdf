import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../storage/safe_document_storage.dart';
import 'syncfusion_pdf_service.dart';

class PdfFileSummary {
  final int pageCount;
  final int fileSizeBytes;
  final bool isEncrypted;

  const PdfFileSummary({
    required this.pageCount,
    required this.fileSizeBytes,
    this.isEncrypted = false,
  });
}

class PdfMergeSource {
  final String path;
  final List<int>? pageNumbers; // null = all pages (1-based)
  final String? bookmarkTitle;

  const PdfMergeSource({
    required this.path,
    this.pageNumbers,
    this.bookmarkTitle,
  });
}

enum PdfCompressionMode {
  lossless(
    'Lossless Structure Optimization',
    'Keeps 100% vector text & fonts while compacting streams',
  ),
  balanced('Balanced (120 DPI)', 'Ideal for email & crisp screen reading'),
  extreme(
    'Compact Screen (85 DPI)',
    'Smallest footprint for scans & photo-heavy PDFs',
  );

  final String label;
  final String subtitle;
  const PdfCompressionMode(this.label, this.subtitle);
}

class PdfCompressionResult {
  final String outputPath;
  final int originalBytes;
  final int compressedBytes;

  const PdfCompressionResult({
    required this.outputPath,
    required this.originalBytes,
    required this.compressedBytes,
  });

  double get savedPercentage {
    if (originalBytes <= 0) return 0.0;
    return ((originalBytes - compressedBytes) / originalBytes * 100).clamp(
      -999.0,
      100.0,
    );
  }
}

enum PageNumberPosition {
  topLeft('Top Left'),
  topCenter('Top Center'),
  topRight('Top Right'),
  bottomLeft('Bottom Left'),
  bottomCenter('Bottom Center'),
  bottomRight('Bottom Right');

  final String label;
  const PageNumberPosition(this.label);
}

enum PdfEncryptionTier {
  aes256('AES-256 (Maximum)', sf.PdfEncryptionAlgorithm.aesx256Bit),
  aes128('AES-128 (High)', sf.PdfEncryptionAlgorithm.aesx128Bit),
  rc4_128('RC4-128 (Legacy)', sf.PdfEncryptionAlgorithm.rc4x128Bit);

  final String label;
  final sf.PdfEncryptionAlgorithm algorithm;
  const PdfEncryptionTier(this.label, this.algorithm);
}

enum BlankPaperTemplate {
  blank('Blank Canvas', 'Clean empty sheet for freeform notes'),
  lined('Ruled Notebook', 'Classic horizontal lines with left margin rule'),
  grid('Engineering Grid', 'Crisp 5mm architectural / math squares'),
  dotted('Bullet Journal', 'Minimalist dot-matrix guide grid');

  final String label;
  final String subtitle;
  const BlankPaperTemplate(this.label, this.subtitle);
}

/// Advanced, ISO 32000-compliant PDF operations built atop Syncfusion & PDFium.
extension AdvancedPdfOperations on SyncfusionPdfService {
  static final SafeDocumentStorage _storage = SafeDocumentStorage();

  /// Inspects a PDF for page count, file size, and password protection status.
  Future<PdfFileSummary> inspectPdf(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const PdfFileSummary(pageCount: 0, fileSizeBytes: 0);
    }
    final size = await file.length();
    final bytes = await file.readAsBytes();
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return PdfFileSummary(pageCount: count, fileSizeBytes: size);
    } catch (_) {
      return PdfFileSummary(
        pageCount: 0,
        fileSizeBytes: size,
        isEncrypted: true,
      );
    }
  }

  /// Advanced merge supporting custom per-file page ranges, heterogeneous page sizes,
  /// stream compression, and clickable Table of Contents bookmarks per source file.
  Future<String> mergePdfsAdvanced({
    required List<PdfMergeSource> sources,
    required String outputPath,
    bool addBookmarks = true,
  }) async {
    final mergedDoc = sf.PdfDocument();
    mergedDoc.compressionLevel = sf.PdfCompressionLevel.best;
    mergedDoc.fileStructure.incrementalUpdate = false;

    try {
      for (final src in sources) {
        final file = File(src.path);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final srcDoc = sf.PdfDocument(inputBytes: bytes);
        sf.PdfPage? firstPageForSource;

        try {
          final targetPages =
              src.pageNumbers != null && src.pageNumbers!.isNotEmpty
              ? src.pageNumbers!
              : List<int>.generate(srcDoc.pages.count, (i) => i + 1);

          for (final pageNum in targetPages) {
            if (pageNum < 1 || pageNum > srcDoc.pages.count) continue;
            final srcPage = srcDoc.pages[pageNum - 1];
            final template = srcPage.createTemplate();

            final section = mergedDoc.sections!.add();
            section.pageSettings.margins.all = 0;
            section.pageSettings.size = srcPage.size;

            final newPage = section.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              const ui.Offset(0, 0),
              ui.Size(srcPage.size.width, srcPage.size.height),
            );
            firstPageForSource ??= newPage;
          }

          if (addBookmarks &&
              firstPageForSource != null &&
              (src.bookmarkTitle?.trim().isNotEmpty ?? false)) {
            final bm = mergedDoc.bookmarks.add(src.bookmarkTitle!.trim());
            bm.destination = sf.PdfDestination(
              firstPageForSource,
              const ui.Offset(0, 0),
            );
          }
        } finally {
          srcDoc.dispose();
        }
      }

      if (mergedDoc.pages.count == 0) {
        throw StateError('No valid pages found to merge.');
      }

      final mergedBytes = Uint8List.fromList(mergedDoc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: mergedBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Advanced merge save failed');
      }
      return outputPath;
    } finally {
      mergedDoc.dispose();
    }
  }

  /// Splits a PDF into chunks of `pagesPerChunk` inside `outputDirectory`.
  /// Returns list of created file paths.
  Future<List<String>> splitPdfIntoChunks({
    required String sourcePath,
    required String outputDirectory,
    required int pagesPerChunk,
    String? baseName,
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final srcDoc = sf.PdfDocument(inputBytes: bytes);
    final outputs = <String>[];
    final cleanBase = baseName ?? p.basenameWithoutExtension(sourcePath);

    try {
      final totalPages = srcDoc.pages.count;
      final chunkSize = pagesPerChunk.clamp(1, totalPages);
      final totalChunks = (totalPages / chunkSize).ceil();

      for (int chunkIdx = 0; chunkIdx < totalChunks; chunkIdx++) {
        final start = chunkIdx * chunkSize;
        final end = (start + chunkSize).clamp(0, totalPages);

        final chunkDoc = sf.PdfDocument();
        chunkDoc.compressionLevel = sf.PdfCompressionLevel.best;
        try {
          for (int i = start; i < end; i++) {
            final srcPage = srcDoc.pages[i];
            final template = srcPage.createTemplate();
            final section = chunkDoc.sections!.add();
            section.pageSettings.margins.all = 0;
            section.pageSettings.size = srcPage.size;
            final newPage = section.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              const ui.Offset(0, 0),
              ui.Size(srcPage.size.width, srcPage.size.height),
            );
          }

          final fileName = chunkSize == 1
              ? '${cleanBase}_page_${start + 1}.pdf'
              : '${cleanBase}_pages_${start + 1}-$end.pdf';
          final outPath = p.join(outputDirectory, fileName);
          final outBytes = Uint8List.fromList(chunkDoc.saveSync());
          final res = await _storage.transactionalSaveBytes(
            targetPath: outPath,
            bytes: outBytes,
          );
          if (res.isSuccess) {
            outputs.add(outPath);
          }
        } finally {
          chunkDoc.dispose();
        }
        onProgress?.call(chunkIdx + 1, totalChunks);
      }

      return outputs;
    } finally {
      srcDoc.dispose();
    }
  }

  /// Compresses a PDF either structurally (lossless stream optimization) or by
  /// re-rasterizing pages at a chosen DPI via PDFium.
  Future<PdfCompressionResult> compressPdf({
    required String sourcePath,
    required String outputPath,
    PdfCompressionMode mode = PdfCompressionMode.lossless,
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(sourcePath);
    final originalBytes = await file.readAsBytes();

    Uint8List compressedBytes;

    if (mode == PdfCompressionMode.lossless) {
      final doc = sf.PdfDocument(inputBytes: originalBytes);
      try {
        doc.compressionLevel = sf.PdfCompressionLevel.best;
        doc.fileStructure.incrementalUpdate = false;
        doc.fileStructure.crossReferenceType =
            sf.PdfCrossReferenceType.crossReferenceStream;
        compressedBytes = Uint8List.fromList(doc.saveSync());
      } finally {
        doc.dispose();
      }
    } else {
      final dpi = mode == PdfCompressionMode.balanced ? 120.0 : 85.0;
      final pdfrxDoc = await pdfrx.PdfDocument.openFile(sourcePath);
      final outDoc = sf.PdfDocument();
      outDoc.compressionLevel = sf.PdfCompressionLevel.best;
      outDoc.fileStructure.incrementalUpdate = false;

      try {
        final total = pdfrxDoc.pages.length;
        for (int i = 0; i < total; i++) {
          final page = pdfrxDoc.pages[i];
          final scale = dpi / 72.0;
          final targetW = (page.width * scale).round().clamp(1, 4096);
          final targetH = (page.height * scale).round().clamp(1, 4096);

          final pdfImg = await page.render(width: targetW, height: targetH);
          if (pdfImg != null) {
            final uiImg = await pdfImg.createImage();
            final pngData = await uiImg.toByteData(
              format: ui.ImageByteFormat.png,
            );
            uiImg.dispose();
            pdfImg.dispose();

            if (pngData != null) {
              final bitmap = sf.PdfBitmap(pngData.buffer.asUint8List());
              final section = outDoc.sections!.add();
              section.pageSettings.margins.all = 0;
              section.pageSettings.size = ui.Size(page.width, page.height);
              final newPage = section.pages.add();
              newPage.graphics.drawImage(
                bitmap,
                ui.Rect.fromLTWH(0, 0, page.width, page.height),
              );
            }
          }
          onProgress?.call(i + 1, total);
        }
        compressedBytes = Uint8List.fromList(outDoc.saveSync());
      } finally {
        await pdfrxDoc.dispose();
        outDoc.dispose();
      }
    }

    final res = await _storage.transactionalSaveBytes(
      targetPath: outputPath,
      bytes: compressedBytes,
    );
    if (!res.isSuccess) {
      throw StateError(res.errorMessage ?? 'Compression save failed');
    }

    return PdfCompressionResult(
      outputPath: outputPath,
      originalBytes: originalBytes.length,
      compressedBytes: compressedBytes.length,
    );
  }

  /// Renders selected PDF pages to high-DPI PNG image files via native PDFium.
  Future<List<String>> exportPagesToPngs({
    required String sourcePath,
    required String outputDirectory,
    required List<int> pageNumbers, // 1-based
    int dpi = 150,
    String? filePrefix,
    void Function(int current, int total)? onProgress,
  }) async {
    final doc = await pdfrx.PdfDocument.openFile(sourcePath);
    final outputs = <String>[];
    final cleanPrefix = filePrefix ?? p.basenameWithoutExtension(sourcePath);

    try {
      final scale = dpi / 72.0;
      for (int idx = 0; idx < pageNumbers.length; idx++) {
        final pageNum = pageNumbers[idx];
        if (pageNum < 1 || pageNum > doc.pages.length) continue;

        final page = doc.pages[pageNum - 1];
        final w = (page.width * scale).round().clamp(1, 8192);
        final h = (page.height * scale).round().clamp(1, 8192);

        final pdfImg = await page.render(width: w, height: h);
        if (pdfImg != null) {
          final uiImg = await pdfImg.createImage();
          final pngData = await uiImg.toByteData(
            format: ui.ImageByteFormat.png,
          );
          uiImg.dispose();
          pdfImg.dispose();

          if (pngData != null) {
            final padded = pageNum.toString().padLeft(3, '0');
            final outFile = File(
              p.join(outputDirectory, '${cleanPrefix}_p$padded.png'),
            );
            await outFile.writeAsBytes(
              pngData.buffer.asUint8List(),
              flush: true,
            );
            outputs.add(outFile.path);
          }
        }
        onProgress?.call(idx + 1, pageNumbers.length);
      }
      return outputs;
    } finally {
      await doc.dispose();
    }
  }

  /// Adds a crisp vector watermark stamp across selected pages.
  Future<String> addWatermark({
    required String sourcePath,
    required String outputPath,
    required String text,
    double fontSize = 48,
    double opacity = 0.25,
    double angleDegrees = -45,
    Color color = const Color(0xFFDC2626),
    List<int>? pageNumbers, // null = all pages
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        fontSize,
        style: sf.PdfFontStyle.bold,
      );
      final r = (color.r * 255).round();
      final g = (color.g * 255).round();
      final b = (color.b * 255).round();
      final brush = sf.PdfSolidBrush(sf.PdfColor(r, g, b));
      final textSize = font.measureString(text);
      final targetSet = pageNumbers?.toSet();

      for (int i = 0; i < doc.pages.count; i++) {
        if (targetSet != null && !targetSet.contains(i + 1)) continue;
        final page = doc.pages[i];
        final graphics = page.graphics;
        final size = page.getClientSize();

        graphics.save();
        graphics.setTransparency(opacity.clamp(0.05, 1.0));
        graphics.translateTransform(size.width / 2, size.height / 2);
        graphics.rotateTransform(angleDegrees);
        graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: ui.Rect.fromLTWH(
            -textSize.width / 2 - 10,
            -textSize.height / 2 - 4,
            textSize.width + 20,
            textSize.height + 8,
          ),
        );
        graphics.restore();
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Watermark save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Adds formatted page numbers or Bates stamps (`{n}`, `{total}`, `{bates}`).
  Future<String> addPageNumbers({
    required String sourcePath,
    required String outputPath,
    PageNumberPosition position = PageNumberPosition.bottomCenter,
    String format = 'Page {n} of {total}',
    int startNumber = 1,
    int batesPadding = 4,
    bool skipFirstPage = false,
    double fontSize = 11,
    Color color = const Color(0xFF334155),
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final totalPages = doc.pages.count;
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize);
      final r = (color.r * 255).round();
      final g = (color.g * 255).round();
      final b = (color.b * 255).round();
      final brush = sf.PdfSolidBrush(sf.PdfColor(r, g, b));

      for (int i = 0; i < totalPages; i++) {
        if (skipFirstPage && i == 0) continue;
        final page = doc.pages[i];
        final clientSize = page.getClientSize();
        final currentNum = startNumber + (skipFirstPage ? i - 1 : i);
        final effectiveTotal = skipFirstPage ? totalPages - 1 : totalPages;

        final label = format
            .replaceAll('{n}', '$currentNum')
            .replaceAll('{total}', '$effectiveTotal')
            .replaceAll(
              '{bates}',
              currentNum.toString().padLeft(batesPadding, '0'),
            );

        final measured = font.measureString(label);
        const edgePad = 24.0;

        late final double x;
        switch (position) {
          case PageNumberPosition.topLeft:
          case PageNumberPosition.bottomLeft:
            x = edgePad;
            break;
          case PageNumberPosition.topCenter:
          case PageNumberPosition.bottomCenter:
            x = (clientSize.width - measured.width) / 2;
            break;
          case PageNumberPosition.topRight:
          case PageNumberPosition.bottomRight:
            x = clientSize.width - measured.width - edgePad;
            break;
        }

        final isTop =
            position == PageNumberPosition.topLeft ||
            position == PageNumberPosition.topCenter ||
            position == PageNumberPosition.topRight;
        final y = isTop
            ? edgePad
            : (clientSize.height - measured.height - edgePad);

        page.graphics.drawString(
          label,
          font,
          brush: brush,
          bounds: ui.Rect.fromLTWH(
            x.clamp(0.0, clientSize.width),
            y.clamp(0.0, clientSize.height),
            measured.width + 12,
            measured.height + 6,
          ),
        );
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Page numbering save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Protects a PDF with selectable encryption strength and granular permission flags.
  Future<String> protectPdfWithOptions({
    required String sourcePath,
    required String outputPath,
    required String userPassword,
    String? ownerPassword,
    PdfEncryptionTier tier = PdfEncryptionTier.aes256,
    bool allowPrint = true,
    bool allowCopy = false,
    bool allowModify = false,
    bool allowFillForms = true,
    bool allowAnnotations = true,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);

    try {
      final sec = doc.security;
      sec.userPassword = userPassword;
      sec.ownerPassword = (ownerPassword != null && ownerPassword.isNotEmpty)
          ? ownerPassword
          : userPassword;
      sec.algorithm = tier.algorithm;
      sec.permissions.clear();

      if (allowPrint) {
        sec.permissions.add(sf.PdfPermissionsFlags.print);
        sec.permissions.add(sf.PdfPermissionsFlags.fullQualityPrint);
      }
      if (allowCopy) {
        sec.permissions.add(sf.PdfPermissionsFlags.copyContent);
      }
      if (allowModify) {
        sec.permissions.add(sf.PdfPermissionsFlags.editContent);
        sec.permissions.add(sf.PdfPermissionsFlags.assembleDocument);
      }
      if (allowFillForms) {
        sec.permissions.add(sf.PdfPermissionsFlags.fillFields);
      }
      if (allowAnnotations) {
        sec.permissions.add(sf.PdfPermissionsFlags.editAnnotations);
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
        password: userPassword.isNotEmpty ? userPassword : sec.ownerPassword,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Protect save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Unlocks / removes encryption and permission locks from a password-protected PDF.
  Future<String> unlockPdf({
    required String sourcePath,
    required String currentPassword,
    required String outputPath,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final srcDoc = sf.PdfDocument(inputBytes: bytes, password: currentPassword);
    final unlockedDoc = sf.PdfDocument();
    unlockedDoc.compressionLevel = sf.PdfCompressionLevel.best;

    try {
      for (int i = 0; i < srcDoc.pages.count; i++) {
        final srcPage = srcDoc.pages[i];
        final template = srcPage.createTemplate();
        final section = unlockedDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = srcPage.size;
        final newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const ui.Offset(0, 0),
          ui.Size(srcPage.size.width, srcPage.size.height),
        );
      }

      final outBytes = Uint8List.fromList(unlockedDoc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Unlock save failed');
      }
      return outputPath;
    } finally {
      srcDoc.dispose();
      unlockedDoc.dispose();
    }
  }

  /// Generates a multi-page custom PDF notebook / structured stationery document.
  Future<String> createTemplatedDocument({
    required String title,
    required String outputPath,
    BlankPaperTemplate template = BlankPaperTemplate.blank,
    ui.Size pageSize = sf.PdfPageSize.a4,
    int pageCount = 1,
    Color backgroundColor = const Color(0xFFFFFFFF),
  }) async {
    final doc = sf.PdfDocument();
    doc.documentInformation.title = title;
    doc.pageSettings.margins.all = 0;
    doc.pageSettings.size = pageSize;

    try {
      final bgR = (backgroundColor.r * 255).round();
      final bgG = (backgroundColor.g * 255).round();
      final bgB = (backgroundColor.b * 255).round();
      final bgBrush = sf.PdfSolidBrush(sf.PdfColor(bgR, bgG, bgB));

      final isDarkPaper = backgroundColor.computeLuminance() < 0.35;
      final linePen = sf.PdfPen(
        isDarkPaper ? sf.PdfColor(120, 165, 225) : sf.PdfColor(203, 213, 225),
        width: 0.75,
      );
      final marginPen = sf.PdfPen(
        isDarkPaper ? sf.PdfColor(248, 113, 113) : sf.PdfColor(244, 114, 182),
        width: 1.0,
      );

      for (int pIdx = 0; pIdx < pageCount.clamp(1, 100); pIdx++) {
        final page = doc.pages.add();
        final w = page.size.width;
        final h = page.size.height;
        final g = page.graphics;

        // Paper background fill
        g.drawRectangle(brush: bgBrush, bounds: ui.Rect.fromLTWH(0, 0, w, h));

        switch (template) {
          case BlankPaperTemplate.blank:
            break;
          case BlankPaperTemplate.lined:
            g.drawLine(marginPen, const ui.Offset(64, 0), ui.Offset(64, h));
            for (double y = 72; y < h - 36; y += 24) {
              g.drawLine(linePen, ui.Offset(24, y), ui.Offset(w - 24, y));
            }
            break;
          case BlankPaperTemplate.grid:
            const step = 18.0;
            for (double x = 24; x <= w - 24; x += step) {
              g.drawLine(linePen, ui.Offset(x, 24), ui.Offset(x, h - 24));
            }
            for (double y = 24; y <= h - 24; y += step) {
              g.drawLine(linePen, ui.Offset(24, y), ui.Offset(w - 24, y));
            }
            break;
          case BlankPaperTemplate.dotted:
            final dotBrush = sf.PdfSolidBrush(
              isDarkPaper
                  ? sf.PdfColor(148, 163, 184)
                  : sf.PdfColor(148, 163, 184),
            );
            const step = 18.0;
            for (double x = 28; x <= w - 28; x += step) {
              for (double y = 28; y <= h - 28; y += step) {
                g.drawEllipse(
                  ui.Rect.fromCircle(center: ui.Offset(x, y), radius: 0.9),
                  brush: dotBrush,
                );
              }
            }
            break;
        }
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Template document save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }

  /// Builds a custom-formatted PDF from images with full page size, orientation, and margin controls.
  Future<String> buildPdfFromImagesAdvanced({
    required List<String> imagePaths,
    required String outputPath,
    ui.Size? fixedPageSize, // null = fit exact image dimensions
    bool landscape = false,
    double margin = 18.0,
  }) async {
    final doc = sf.PdfDocument();
    doc.compressionLevel = sf.PdfCompressionLevel.best;

    try {
      for (final imgPath in imagePaths) {
        final file = File(imgPath);
        if (!await file.exists()) continue;

        final imgBytes = await file.readAsBytes();
        final bitmap = sf.PdfBitmap(imgBytes);
        final imgW = bitmap.width.toDouble();
        final imgH = bitmap.height.toDouble();

        final section = doc.sections!.add();
        section.pageSettings.margins.all = 0;

        late ui.Size targetSize;
        if (fixedPageSize == null) {
          targetSize = ui.Size(imgW + margin * 2, imgH + margin * 2);
        } else {
          targetSize = landscape
              ? ui.Size(fixedPageSize.height, fixedPageSize.width)
              : fixedPageSize;
        }
        section.pageSettings.size = targetSize;

        final page = section.pages.add();
        final availW = (targetSize.width - margin * 2).clamp(
          10.0,
          targetSize.width,
        );
        final availH = (targetSize.height - margin * 2).clamp(
          10.0,
          targetSize.height,
        );

        final scale = (availW / imgW) < (availH / imgH)
            ? (availW / imgW)
            : (availH / imgH);
        final drawW = imgW * scale;
        final drawH = imgH * scale;
        final offsetX = (targetSize.width - drawW) / 2;
        final offsetY = (targetSize.height - drawH) / 2;

        page.graphics.drawImage(
          bitmap,
          ui.Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        );
      }

      if (doc.pages.count == 0) {
        throw StateError('No valid image files provided.');
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      final res = await _storage.transactionalSaveBytes(
        targetPath: outputPath,
        bytes: outBytes,
      );
      if (!res.isSuccess) {
        throw StateError(res.errorMessage ?? 'Images to PDF save failed');
      }
      return outputPath;
    } finally {
      doc.dispose();
    }
  }
}
