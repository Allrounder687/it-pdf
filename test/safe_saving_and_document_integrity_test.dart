import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/storage/safe_document_storage.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'fixtures/pdf_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SafeDocumentStorage storage;
  late File fixtureFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('it_pdf_safe_save_test_');
    storage = SafeDocumentStorage();
    final fixturePath = p.join(tempDir.path, 'source_doc.pdf');
    fixtureFile = await PdfTestFixtures.createComplexForensicPdfFixture(
      targetPath: fixturePath,
    );
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('SafeDocumentStorage — Document Integrity & Transactional Persistence', () {
    test(
      'createWorkingCopy isolates source document into a unique working file',
      () async {
        final workingPath = await storage.createWorkingCopy(fixtureFile.path);

        expect(workingPath, isNot(equals(fixtureFile.path)));
        expect(File(workingPath).existsSync(), isTrue);

        final originalBytes = await fixtureFile.readAsBytes();
        final workingBytes = await File(workingPath).readAsBytes();
        expect(workingBytes.length, equals(originalBytes.length));
        expect(workingBytes, equals(originalBytes));
      },
    );

    test(
      'validatePdfBytes accepts valid PDFs and rejects corrupt byte streams',
      () async {
        final validBytes = await fixtureFile.readAsBytes();
        expect(storage.validatePdfBytes(validBytes), isTrue);

        // Rejects truncated or garbage bytes
        final garbageBytes = Uint8List.fromList(
          utf8.encode('Hello, this is plain text, not a PDF'),
        );
        expect(storage.validatePdfBytes(garbageBytes), isFalse);

        // Rejects fake header without valid PDF structure
        final fakeHeaderBytes = Uint8List.fromList(
          utf8.encode(
            '%PDF-1.7\nCorrupted stream data with no xref or trailer',
          ),
        );
        expect(storage.validatePdfBytes(fakeHeaderBytes), isFalse);
      },
    );

    test(
      'transactionalSaveBytes saves valid PDF atomically with backup',
      () async {
        final targetPath = p.join(tempDir.path, 'transactional_target.pdf');
        final validBytes = await fixtureFile.readAsBytes();

        final result = await storage.transactionalSaveBytes(
          targetPath: targetPath,
          bytes: validBytes,
          createBackup: true,
        );

        expect(result.isSuccess, isTrue);
        expect(File(targetPath).existsSync(), isTrue);

        // Verify the saved file is independently readable by Syncfusion
        final savedDoc = sf.PdfDocument(
          inputBytes: await File(targetPath).readAsBytes(),
        );
        expect(savedDoc.pages.count, equals(3));
        savedDoc.dispose();
      },
    );

    test(
      'transactionalSaveBytes rejects corrupt bytes and preserves existing destination untouched',
      () async {
        final targetPath = fixtureFile.path;
        final originalBytes = await fixtureFile.readAsBytes();

        final corruptBytes = Uint8List.fromList(
          utf8.encode('Corrupted PDF bytes payload'),
        );
        final result = await storage.transactionalSaveBytes(
          targetPath: targetPath,
          bytes: corruptBytes,
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Validation failed'));

        // Ensure the original file on disk was NEVER overwritten or corrupted
        final currentDiskBytes = await fixtureFile.readAsBytes();
        expect(currentDiskBytes, equals(originalBytes));
      },
    );

    test(
      'recoverInterruptedSaves restores interrupted transactional saves from backup',
      () async {
        final targetPath = p.join(tempDir.path, 'critical_document.pdf');
        final backupPath = p.join(
          tempDir.path,
          '.critical_document.pdf.bak_12345678',
        );
        final journalPath = p.join(
          tempDir.path,
          '.critical_document.pdf.journal',
        );

        // Setup state: backup exists with valid bytes, target is missing (simulating mid-crash failure)
        final validBytes = await fixtureFile.readAsBytes();
        await File(backupPath).writeAsBytes(validBytes, flush: true);

        final journalData = {
          'targetPath': targetPath,
          'backupPath': backupPath,
          'tempPath': p.join(
            tempDir.path,
            '.critical_document.pdf.staging_abc.tmp',
          ),
          'timestamp': 12345678,
        };
        await File(
          journalPath,
        ).writeAsString(jsonEncode(journalData), flush: true);

        expect(File(targetPath).existsSync(), isFalse);

        // Run recovery
        final recoveredCount = await storage.recoverInterruptedSaves(
          tempDir.path,
        );

        expect(recoveredCount, equals(1));
        expect(File(targetPath).existsSync(), isTrue);

        final restoredDoc = sf.PdfDocument(
          inputBytes: await File(targetPath).readAsBytes(),
        );
        expect(restoredDoc.pages.count, equals(3));
        restoredDoc.dispose();

        // Journal should be cleanly disposed
        expect(File(journalPath).existsSync(), isFalse);
      },
    );
  });
}
