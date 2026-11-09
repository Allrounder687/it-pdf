import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Encapsulates embedded PDF attachment metadata and payload.
class PdfAttachmentInfo {
  final String fileName;
  final int sizeInBytes;
  final String? description;
  final String? mimeType;
  final Uint8List data;

  const PdfAttachmentInfo({
    required this.fileName,
    required this.sizeInBytes,
    this.description,
    this.mimeType,
    required this.data,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Comprehensive ISO metadata inspection results for a PDF document.
class PdfDocumentProperties {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final String pdfVersion;
  final String? title;
  final String? author;
  final String? subject;
  final String? keywords;
  final String? creator;
  final String? producer;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final double pageWidth;
  final double pageHeight;
  final bool isEncrypted;
  final int attachmentCount;

  const PdfDocumentProperties({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.pdfVersion,
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
    this.creationDate,
    this.modificationDate,
    required this.pageWidth,
    required this.pageHeight,
    required this.isEncrypted,
    required this.attachmentCount,
  });

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get standardPageSizeName {
    final w = pageWidth;
    final h = pageHeight;
    final minDim = w < h ? w : h;
    final maxDim = w < h ? h : w;

    if ((minDim - 595.28).abs() < 5 && (maxDim - 841.89).abs() < 5) {
      return 'A4 (${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt)';
    }
    if ((minDim - 612.0).abs() < 5 && (maxDim - 792.0).abs() < 5) {
      return 'Letter (${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt)';
    }
    if ((minDim - 612.0).abs() < 5 && (maxDim - 1008.0).abs() < 5) {
      return 'Legal (${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt)';
    }
    if ((minDim - 419.53).abs() < 5 && (maxDim - 595.28).abs() < 5) {
      return 'A5 (${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt)';
    }
    if ((minDim - 841.89).abs() < 5 && (maxDim - 1190.55).abs() < 5) {
      return 'A3 (${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt)';
    }

    final inW = (w / 72.0).toStringAsFixed(2);
    final inH = (h / 72.0).toStringAsFixed(2);
    final mmW = (w * 25.4 / 72.0).toStringAsFixed(0);
    final mmH = (h * 25.4 / 72.0).toStringAsFixed(0);
    return 'Custom: ${w.toStringAsFixed(1)} x ${h.toStringAsFixed(1)} pt ($inW x $inH in / $mmW x $mmH mm)';
  }
}

/// Service providing ISO PDF metadata inspection and attachment extraction.
class PdfMetadataService {
  const PdfMetadataService();

  /// Inspects a PDF document and extracts full ISO document properties.
  Future<PdfDocumentProperties> inspectDocument(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('PDF file does not exist at path', filePath);
    }

    final bytes = await file.readAsBytes();
    final fileSizeBytes = bytes.length;
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;

    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      final info = doc.documentInformation;
      final pageCount = doc.pages.count;
      double width = 0.0;
      double height = 0.0;
      if (pageCount > 0) {
        final size = doc.pages[0].size;
        width = size.width;
        height = size.height;
      }

      final versionStr = 'PDF ${_formatVersion(doc.fileStructure.version)}';
      final attachmentCount = doc.attachments.count;
      final isEncrypted =
          doc.security.userPassword.isNotEmpty ||
          doc.security.ownerPassword.isNotEmpty;

      return PdfDocumentProperties(
        fileName: fileName,
        filePath: filePath,
        fileSizeBytes: fileSizeBytes,
        pageCount: pageCount,
        pdfVersion: versionStr,
        title: (info.title.isNotEmpty) ? info.title : null,
        author: (info.author.isNotEmpty) ? info.author : null,
        subject: (info.subject.isNotEmpty) ? info.subject : null,
        keywords: (info.keywords.isNotEmpty) ? info.keywords : null,
        creator: (info.creator.isNotEmpty) ? info.creator : null,
        producer: (info.producer.isNotEmpty) ? info.producer : null,
        creationDate: info.creationDate,
        modificationDate: info.modificationDate,
        pageWidth: width,
        pageHeight: height,
        isEncrypted: isEncrypted,
        attachmentCount: attachmentCount,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Extracts all embedded attachments from the PDF document.
  Future<List<PdfAttachmentInfo>> extractAttachments(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return const [];

    final bytes = await file.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      final list = <PdfAttachmentInfo>[];
      final count = doc.attachments.count;
      for (int i = 0; i < count; i++) {
        final att = doc.attachments[i];
        list.add(
          PdfAttachmentInfo(
            fileName: att.fileName,
            sizeInBytes: att.data.length,
            description: att.description.isNotEmpty ? att.description : null,
            mimeType: att.mimeType.isNotEmpty ? att.mimeType : null,
            data: Uint8List.fromList(att.data),
          ),
        );
      }
      return list;
    } finally {
      doc.dispose();
    }
  }

  /// Exports an attachment to the designated destination path.
  Future<bool> exportAttachment({
    required PdfAttachmentInfo attachment,
    required String targetPath,
  }) async {
    try {
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(attachment.data, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _formatVersion(sf.PdfVersion version) {
    switch (version) {
      case sf.PdfVersion.version1_0:
        return '1.0';
      case sf.PdfVersion.version1_1:
        return '1.1';
      case sf.PdfVersion.version1_2:
        return '1.2';
      case sf.PdfVersion.version1_3:
        return '1.3';
      case sf.PdfVersion.version1_4:
        return '1.4';
      case sf.PdfVersion.version1_5:
        return '1.5';
      case sf.PdfVersion.version1_6:
        return '1.6';
      case sf.PdfVersion.version1_7:
        return '1.7';
      default:
        return '1.7';
    }
  }
}
