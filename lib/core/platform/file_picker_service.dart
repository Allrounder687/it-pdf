import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../logging/app_logger.dart';

/// Platform-agnostic file selection and destination picker.
class FilePickerService {
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
      AppLogger.error('Error picking multiple PDF files', error: e, stackTrace: st);
      return [];
    }
  }

  /// Open native file picker to select images (for PDF conversion).
  Future<List<String>> pickImageFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      return result
          .where((PlatformFile f) => f.path != null)
          .map((PlatformFile f) => f.path!)
          .toList();
    } catch (e, st) {
      AppLogger.error('Error picking image files', error: e, stackTrace: st);
      return [];
    }
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
      return uri.path;
    } catch (e, st) {
      AppLogger.error('Error saving PDF bytes via file picker', error: e, stackTrace: st);
      return null;
    }
  }

  /// Prompt user to choose export/save path for a PDF file or return default safe path.
  Future<String?> getSaveDestinationPath({required String defaultFileName}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final destination = p.join(dir.path, defaultFileName);
      return destination;
    } catch (e, st) {
      AppLogger.error('Error obtaining save destination path', error: e, stackTrace: st);
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
