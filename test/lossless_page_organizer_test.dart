import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/core/storage/safe_document_storage.dart';
import 'package:it_pdf/features/page_organizer/domain/page_item.dart';
import 'package:it_pdf/features/page_organizer/domain/page_organizer_service.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'fixtures/pdf_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SafeDocumentStorage storage;
  late PageOrganizerService organizerService;
  late File fixtureFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('it_pdf_organizer_test_');
    storage = SafeDocumentStorage();
    organizerService = PageOrganizerService(safeStorage: storage);
    final fixturePath = p.join(tempDir.path, 'source_organizer.pdf');
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

  group('PageOrganizerService — Lossless Page Operations & Document Semantics', () {
    test(
      'applyOrganizerChanges surgically deletes pages without destroying surviving AcroForms',
      () async {
        final outputPath = p.join(tempDir.path, 'deleted_page_output.pdf');

        // Keep only Page 2 (which has interactive AcroForms) and Page 3 (which has hyperlinks)
        final workspacePages = [
          const PageItem(
            originalPageNumber: 2,
            currentPosition: 1,
            rotationDegrees: 0,
          ),
          const PageItem(
            originalPageNumber: 3,
            currentPosition: 2,
            rotationDegrees: 90,
          ),
        ];

        await organizerService.applyOrganizerChanges(
          sourcePath: fixtureFile.path,
          workspacePages: workspacePages,
          originalPageCount: 3,
          outputPath: outputPath,
        );

        expect(File(outputPath).existsSync(), isTrue);

        // Reopen document independently
        final doc = sf.PdfDocument(
          inputBytes: await File(outputPath).readAsBytes(),
        );
        expect(doc.pages.count, equals(2));

        // Page 1 of the new document was Page 2 of the original: must have preserved AcroForms!
        expect(doc.form.fields.count, greaterThanOrEqualTo(3));
        final fieldNames = <String>[];
        for (int i = 0; i < doc.form.fields.count; i++) {
          fieldNames.add(doc.form.fields[i].name ?? '');
        }
        expect(fieldNames, contains('full_name'));
        expect(fieldNames, contains('email_address'));
        expect(fieldNames, contains('region_selector'));

        doc.dispose();
      },
    );

    test(
      'applyOrganizerChanges updates page rotations directly in the page tree',
      () async {
        final outputPath = p.join(tempDir.path, 'rotated_output.pdf');

        final workspacePages = [
          const PageItem(
            originalPageNumber: 1,
            currentPosition: 1,
            rotationDegrees: 90,
          ),
          const PageItem(
            originalPageNumber: 2,
            currentPosition: 2,
            rotationDegrees: 180,
          ),
          const PageItem(
            originalPageNumber: 3,
            currentPosition: 3,
            rotationDegrees: 270,
          ),
        ];

        await organizerService.applyOrganizerChanges(
          sourcePath: fixtureFile.path,
          workspacePages: workspacePages,
          originalPageCount: 3,
          outputPath: outputPath,
        );

        final doc = sf.PdfDocument(
          inputBytes: await File(outputPath).readAsBytes(),
        );
        expect(doc.pages.count, equals(3));
        expect(
          doc.pages[0].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle90),
        );
        expect(
          doc.pages[1].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle180),
        );
        expect(
          doc.pages[2].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle270),
        );
        doc.dispose();
      },
    );

    test(
      'exportSelectedPages creates standalone document with exact page structure',
      () async {
        final outputPath = p.join(tempDir.path, 'extracted_page2.pdf');

        await organizerService.exportSelectedPages(
          sourcePath: fixtureFile.path,
          pageNumbers: [2],
          outputPath: outputPath,
        );

        final doc = sf.PdfDocument(
          inputBytes: await File(outputPath).readAsBytes(),
        );
        expect(doc.pages.count, equals(1));
        expect(doc.form.fields.count, greaterThanOrEqualTo(2));
        doc.dispose();
      },
    );

    test(
      'applyOrganizerChanges handles complex reordering and duplicate pages',
      () async {
        final outputPath = p.join(tempDir.path, 'reordered_output.pdf');

        // Reorder to [3, 1, 2, 1] (includes a duplicate of Page 1)
        final workspacePages = [
          const PageItem(
            originalPageNumber: 3,
            currentPosition: 1,
            rotationDegrees: 90,
          ),
          const PageItem(
            originalPageNumber: 1,
            currentPosition: 2,
            rotationDegrees: 0,
          ),
          const PageItem(
            originalPageNumber: 2,
            currentPosition: 3,
            rotationDegrees: 0,
          ),
          const PageItem(
            originalPageNumber: 1,
            currentPosition: 4,
            rotationDegrees: 0,
          ),
        ];

        await organizerService.applyOrganizerChanges(
          sourcePath: fixtureFile.path,
          workspacePages: workspacePages,
          originalPageCount: 3,
          outputPath: outputPath,
        );

        final doc = sf.PdfDocument(
          inputBytes: await File(outputPath).readAsBytes(),
        );
        expect(doc.pages.count, equals(4));
        // First page in output should have rotation 90 (originating from page 3)
        expect(
          doc.pages[0].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle90),
        );
        doc.dispose();
      },
    );
  });
}
