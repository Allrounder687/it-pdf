import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../logging/app_logger.dart';

/// Platform-agnostic file selection, mobile-safe writable output routing, and export service.
class FilePickerService {
  static bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;

  /// Open native file picker to select a single PDF document.
  Future<String?> pickPdfFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      return result?.path;
    } catch (e, st) {
      AppLogger.error('Error picking PDF file', error: e, stackTrace: st);
      return null;
    }
  }

  /// Open native file picker to select multiple PDF files (e.g. for merging).
  Future<List<String>> pickMultiplePdfFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      return result
          .where((PlatformFile f) => f.path != null)
          .map((PlatformFile f) => f.path!)
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'Error picking multiple PDF files',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Open native file picker to select images (for PDF conversion).
  Future<List<String>> pickImageFiles() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      return result
          .where((PlatformFile f) => f.path != null)
          .map((PlatformFile f) => f.path!)
          .toList();
    } catch (e, st) {
      AppLogger.error('Error picking image files', error: e, stackTrace: st);
      return [];
    }
  }

  /// Save bytes directly via the platform's native SAF / Files export sheet.
  Future<bool> exportFileToDevice({
    required String sourceFilePath,
    required String exportFileName,
    String mimeType = 'application/pdf',
  }) async {
    try {
      final file = File(sourceFilePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();

      if (_isMobilePlatform) {
        final uri = await FilePicker.saveFile(
          fileName: exportFileName,
          bytes: bytes,
          mimeType: mimeType,
        );
        if (uri != null) return true;
        await SharePlus.instance.share(
          ShareParams(files: [XFile(sourceFilePath)]),
        );
        return true;
      }

      final uri = await FilePicker.saveFile(
        fileName: exportFileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      return uri != null;
    } catch (e, st) {
      AppLogger.error(
        'Error exporting file to device',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Resolves a guaranteed local writable filesystem path for generated tool outputs.
  /// - Desktop: opens native Save As file dialog.
  /// - Android/iOS: routes safely into writable app documents `IT_PDF_Output/` folder
  ///   to avoid Android SAF read-only `/document` URI filesystem crashes (`errno = 30`).
  Future<String?> resolveWritableOutputPath({
    required String defaultFileName,
    String? dialogTitle,
    Uint8List? initialBytes,
  }) async {
    if (_isMobilePlatform) {
      final docsDir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(docsDir.path, 'IT_PDF_Output'));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final base = p.basenameWithoutExtension(defaultFileName);
      final ext = p.extension(defaultFileName).isEmpty
          ? '.pdf'
          : p.extension(defaultFileName);
      var candidate = p.join(outDir.path, '$base$ext');
      int suffix = 1;
      while (await File(candidate).exists()) {
        candidate = p.join(outDir.path, '${base}_$suffix$ext');
        suffix++;
      }
      return candidate;
    }

    return pickSaveFilePath(
      defaultFileName: defaultFileName,
      initialBytes: initialBytes,
      dialogTitle: dialogTitle,
    );
  }

  /// Resolves a guaranteed local writable folder for multi-file batch exports.
  Future<String?> resolveWritableOutputDirectory({
    String? dialogTitle,
    required String subFolderName,
  }) async {
    if (!_isMobilePlatform) {
      final picked = await pickDirectoryPath(dialogTitle: dialogTitle);
      if (picked != null && picked.isNotEmpty) return picked;
      return null;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(
        docsDir.path,
        'IT_PDF_Exports',
        '${subFolderName}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Save PDF bytes directly using the platform native save dialog.
  Future<String?> savePdfBytes({
    required String defaultFileName,
    required Uint8List bytes,
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: defaultFileName,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (uri == null) return null;
      if (uri.scheme == 'file') return uri.toFilePath();
      if (_isMobilePlatform) {
        final docsDir = await getApplicationDocumentsDirectory();
        final fallback = p.join(docsDir.path, defaultFileName);
        await File(fallback).writeAsBytes(bytes, flush: true);
        return fallback;
      }
      return uri.path;
    } catch (e, st) {
      AppLogger.error(
        'Error saving PDF bytes via file picker',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Prompt user to choose export/save path using native platform save dialog.
  Future<String?> pickSaveFilePath({
    required String defaultFileName,
    Uint8List? initialBytes,
    String? dialogTitle,
  }) async {
    if (_isMobilePlatform) {
      return resolveWritableOutputPath(
        defaultFileName: defaultFileName,
        dialogTitle: dialogTitle,
      );
    }

    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: defaultFileName,
        bytes: initialBytes ?? Uint8List(0),
      );
      if (uri == null) return null;
      if (uri.scheme == 'file') return uri.toFilePath();
      return getSaveDestinationPath(defaultFileName: defaultFileName);
    } catch (e, st) {
      AppLogger.error('Error in pickSaveFilePath', error: e, stackTrace: st);
      return getSaveDestinationPath(defaultFileName: defaultFileName);
    }
  }

  /// Prompt user to pick a target folder/directory (e.g. for batch exports).
  Future<String?> pickDirectoryPath({String? dialogTitle}) async {
    if (_isMobilePlatform) {
      return resolveWritableOutputDirectory(
        dialogTitle: dialogTitle,
        subFolderName: 'export',
      );
    }
    try {
      return await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
    } catch (e, st) {
      AppLogger.error('Error picking directory path', error: e, stackTrace: st);
      return null;
    }
  }

  /// Prompt user to choose export/save path for a PDF file or return default safe path.
  Future<String?> getSaveDestinationPath({
    required String defaultFileName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final destination = p.join(dir.path, defaultFileName);
      return destination;
    } catch (e, st) {
      AppLogger.error(
        'Error obtaining save destination path',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Get file size safely.
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
