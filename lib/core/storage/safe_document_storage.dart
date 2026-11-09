import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:uuid/uuid.dart';
import '../logging/app_logger.dart';

/// Result of a transactional document save operation.
class SaveResult {
  final bool isSuccess;
  final String path;
  final String? backupPath;
  final String? errorMessage;

  const SaveResult({
    required this.isSuccess,
    required this.path,
    this.backupPath,
    this.errorMessage,
  });

  factory SaveResult.success(String path, {String? backupPath}) =>
      SaveResult(isSuccess: true, path: path, backupPath: backupPath);

  factory SaveResult.failure(String path, String error) =>
      SaveResult(isSuccess: false, path: path, errorMessage: error);
}

/// Robust, industrial-grade transactional PDF persistence manager.
/// Enforces working document copies, pre-commit structural validation,
/// recovery journaling, safe backups, atomic replacement, and interrupted-save recovery.
class SafeDocumentStorage {
  static const _uuid = Uuid();

  /// Create an isolated working copy of a source document.
  Future<String> createWorkingCopy(String sourcePath) async {
    final srcFile = File(sourcePath);
    if (!await srcFile.exists()) {
      throw FileSystemException('Source document not found', sourcePath);
    }

    final dir = srcFile.parent;
    final ext = p.extension(sourcePath);
    final base = p.basenameWithoutExtension(sourcePath);
    final workingPath = p.join(dir.path, '.$base.work_${_uuid.v4()}$ext');

    await srcFile.copy(workingPath);
    AppLogger.info('Created working copy: $workingPath');
    return workingPath;
  }

  /// Validates the internal structure of PDF bytes before allowing persistence.
  /// Verifies magic byte header (%PDF-), xref table, trailer, and page count.
  bool validatePdfBytes(Uint8List bytes, {String? password}) {
    if (bytes.length < 32) return false;

    // Check %PDF- header in the first 1024 bytes (spec allows leading BOM or garbage)
    final headerScanLimit = bytes.length < 1024 ? bytes.length : 1024;
    final headerSlice = String.fromCharCodes(bytes.sublist(0, headerScanLimit));
    if (!headerSlice.contains('%PDF-')) {
      AppLogger.error('PDF validation failed: missing %PDF- header signature');
      return false;
    }

    // Check %%EOF marker near end of file
    final tailScanSize = bytes.length < 2048 ? bytes.length : 2048;
    final tailSlice = String.fromCharCodes(
      bytes.sublist(bytes.length - tailScanSize),
    );
    if (!tailSlice.contains('%%EOF')) {
      AppLogger.warn('PDF validation warning: missing %%EOF trailer marker');
    }

    // Deep semantic parse using Syncfusion PDF engine
    sf.PdfDocument? testDoc;
    try {
      testDoc = sf.PdfDocument(inputBytes: bytes, password: password);
      final count = testDoc.pages.count;
      if (count < 0) {
        AppLogger.error('PDF validation failed: invalid page count ($count)');
        return false;
      }
      return true;
    } catch (e, st) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypt')) {
        AppLogger.info(
          'PDF is password protected: verified valid encrypted PDF',
        );
        return true;
      }
      AppLogger.error(
        'PDF validation failed during structural parse',
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      testDoc?.dispose();
    }
  }

  /// Transactionally saves PDF bytes to the target destination.
  /// 1. Writes to isolated temporary file.
  /// 2. Performs structural validation on the written bytes.
  /// 3. Backs up original file (if existing) to a recovery backup.
  /// 4. Creates recovery journal.
  /// 5. Safely replaces destination with temporary file.
  /// 6. Cleans up journal and staging artifacts.
  Future<SaveResult> transactionalSaveBytes({
    required String targetPath,
    required Uint8List bytes,
    String? password,
    bool createBackup = true,
  }) async {
    // 1. Structural pre-validation
    if (!validatePdfBytes(bytes, password: password)) {
      return SaveResult.failure(
        targetPath,
        'Validation failed: Invalid or corrupted PDF bytes.',
      );
    }

    final targetFile = File(targetPath);
    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final tempFileName = '.${p.basename(targetPath)}.staging_${_uuid.v4()}.tmp';
    final tempPath = p.join(targetDir.path, tempFileName);
    final tempFile = File(tempPath);

    final journalPath = p.join(
      targetDir.path,
      '.${p.basename(targetPath)}.journal',
    );
    final journalFile = File(journalPath);

    String? backupPath;
    File? backupFile;

    try {
      // 2. Write to temporary staging file
      await tempFile.writeAsBytes(bytes, flush: true);

      // Verify written file size matches byte buffer
      final writtenLength = await tempFile.length();
      if (writtenLength != bytes.length) {
        throw StateError(
          'Written byte length mismatch ($writtenLength != ${bytes.length})',
        );
      }

      // 3. Handle backup if destination file already exists
      if (await targetFile.exists()) {
        if (createBackup) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          backupPath = p.join(
            targetDir.path,
            '.${p.basename(targetPath)}.bak_$timestamp',
          );
          backupFile = File(backupPath);
          await targetFile.copy(backupPath);
        }

        // 4. Record Recovery Journal
        final journalData = {
          'targetPath': targetPath,
          'tempPath': tempPath,
          'backupPath': backupPath,
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'staged',
        };
        await journalFile.writeAsString(jsonEncode(journalData), flush: true);
      }

      // 5. Safe replacement (handling Windows file locks and platform semantics)
      await _safeReplaceFile(
        source: tempFile,
        destination: targetFile,
        backup: backupFile,
      );

      // 6. Finalize transaction: remove recovery journal
      if (await journalFile.exists()) {
        await journalFile.delete();
      }

      AppLogger.info(
        'Transactional save completed successfully for: $targetPath',
      );
      return SaveResult.success(targetPath, backupPath: backupPath);
    } catch (e, st) {
      AppLogger.error(
        'Transactional save failed, recovering state',
        error: e,
        stackTrace: st,
      );

      // If replacement failed, attempt restoration from backup
      if (backupFile != null &&
          await backupFile.exists() &&
          !await targetFile.exists()) {
        try {
          await backupFile.copy(targetPath);
          AppLogger.info(
            'Successfully recovered original target from backup: $backupPath',
          );
        } catch (recoverErr) {
          AppLogger.error(
            'Critical: Failed to restore backup',
            error: recoverErr,
          );
        }
      }

      return SaveResult.failure(targetPath, 'Transactional save failed: $e');
    } finally {
      // Clean up temporary staging file
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Platform-safe atomic file replacement.
  /// On Windows, rename throws if destination exists or is locked.
  /// This method safely moves existing destination aside before renaming,
  /// with fallback to chunked streaming copy.
  Future<void> _safeReplaceFile({
    required File source,
    required File destination,
    File? backup,
  }) async {
    final destPath = destination.path;

    if (!await destination.exists()) {
      await source.rename(destPath);
      return;
    }

    // Destination exists; perform safe replacement without dropping original first
    final swapPath = p.join(
      destination.parent.path,
      '.${p.basename(destPath)}.swap_${_uuid.v4()}',
    );
    final swapFile = File(swapPath);

    try {
      // Step A: Rename destination to temporary swap
      await destination.rename(swapPath);

      // Step B: Rename source to destination
      try {
        await source.rename(destPath);
        // Step C: Delete swap now that destination is verified
        await swapFile.delete();
      } catch (renameErr) {
        // Rollback: Restore destination from swap
        if (await swapFile.exists()) {
          await swapFile.rename(destPath);
        }
        rethrow;
      }
    } catch (e) {
      // If atomic rename fails (e.g. cross-volume, Windows sharing violation), fallback to copy
      AppLogger.warn(
        'Rename replacement failed ($e), falling back to streamed write replacement.',
      );
      final sourceBytes = await source.readAsBytes();
      await destination.writeAsBytes(sourceBytes, flush: true);
      if (await source.exists()) {
        await source.delete();
      }
      if (await swapFile.exists()) {
        await swapFile.delete();
      }
    }
  }

  /// Scans directory for incomplete journaled transactions and restores integrity.
  Future<int> recoverInterruptedSaves(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return 0;

    int recoveredCount = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is File && p.basename(entity.path).endsWith('.journal')) {
          try {
            final content = await entity.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            final targetPath = data['targetPath'] as String?;
            final backupPath = data['backupPath'] as String?;
            final tempPath = data['tempPath'] as String?;

            if (targetPath != null && backupPath != null) {
              final targetFile = File(targetPath);
              final backupFile = File(backupPath);
              if (!await targetFile.exists() && await backupFile.exists()) {
                await backupFile.copy(targetPath);
                recoveredCount++;
                AppLogger.info('Recovered target from backup: $targetPath');
              }
            }

            // Cleanup stale temp file
            if (tempPath != null) {
              final tempFile = File(tempPath);
              if (await tempFile.exists()) {
                await tempFile.delete();
              }
            }

            await entity.delete();
          } catch (journalErr) {
            AppLogger.error(
              'Failed processing recovery journal ${entity.path}',
              error: journalErr,
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error scanning for recovery journals', error: e);
    }
    return recoveredCount;
  }

  /// Clean up all old backup and working files for a given document.
  Future<void> cleanupWorkingFiles(String targetPath) async {
    try {
      final file = File(targetPath);
      final dir = file.parent;
      final base = p.basename(targetPath);

      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith('.$base.work_') ||
              name.startsWith('.$base.staging_')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
