import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart' hide Rect, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:it_pdf/features/editor/data/pdfium_editing_backend.dart';
import 'package:it_pdf/features/editor/domain/pdf_content_object.dart';
import 'package:it_pdf/features/editor/domain/pdf_edit_transaction.dart';

void main() {
  late String originalResumePath;
  late String editedResumePath;
  late PdfiumEditingBackend backend;

  setUpAll(() async {
    backend = PdfiumEditingBackend();
    originalResumePath =
        '${Directory.systemTemp.path}/test_resume_original.pdf';
    editedResumePath = '${Directory.systemTemp.path}/test_resume_edited.pdf';

    // 1. Generate an authentic Resume PDF with Syncfusion Lossless Vector Engine
    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    final graphics = page.graphics;

    // Fonts
    final headerFont = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      24,
      style: sf.PdfFontStyle.bold,
    );
    final sectionFont = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      14,
      style: sf.PdfFontStyle.bold,
    );
    final bodyFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10);

    // Header Name
    graphics.drawString(
      'Johnathan Doe',
      headerFont,
      brush: sf.PdfSolidBrush(sf.PdfColor(25, 118, 210)),
      bounds: const Rect.fromLTWH(50, 50, 400, 30),
    );

    // Contact details
    graphics.drawString(
      'john.doe@example.com | (555) 123-4567 | San Francisco, CA',
      bodyFont,
      brush: sf.PdfSolidBrush(sf.PdfColor(100, 100, 100)),
      bounds: const Rect.fromLTWH(50, 85, 450, 20),
    );

    // Separator line
    graphics.drawLine(
      sf.PdfPen(sf.PdfColor(200, 200, 200), width: 1.5),
      const Offset(50, 110),
      const Offset(550, 110),
    );

    // Section Heading
    graphics.drawString(
      'Professional Experience',
      sectionFont,
      brush: sf.PdfSolidBrush(sf.PdfColor(33, 33, 33)),
      bounds: const Rect.fromLTWH(50, 125, 300, 24),
    );

    // Experience Paragraph
    graphics.drawString(
      'Senior Software Engineer with 8+ years developing scalable cloud infrastructure and enterprise mobile applications.',
      bodyFont,
      bounds: const Rect.fromLTWH(50, 155, 500, 40),
    );

    final bytes = doc.saveSync();
    doc.dispose();

    await File(originalResumePath).writeAsBytes(bytes);
    expect(File(originalResumePath).existsSync(), isTrue);
  });

  tearDownAll(() async {
    final orig = File(originalResumePath);
    if (orig.existsSync()) orig.deleteSync();
    final edited = File(editedResumePath);
    if (edited.existsSync()) edited.deleteSync();
  });

  test('PHASE 13: End-to-End Real-World Resume Editing & Validation', () async {
    // A. Extract objects from original PDF
    final initialObjects = await backend.extractPageObjects(
      filePath: originalResumePath,
      pageIndex: 0,
    );
    expect(initialObjects, isNotEmpty);

    final textObjects = initialObjects
        .whereType<PdfTextContentObject>()
        .toList();
    expect(textObjects, isNotEmpty);

    // Find Name object
    final nameObj = textObjects.firstWhere(
      (o) => o.text.contains('Johnathan Doe'),
      orElse: () => textObjects.first,
    );
    expect(nameObj.text, contains('Johnathan Doe'));

    // B. Modify Name: Change "Johnathan Doe" to "Alexander Hamilton"
    final modifiedNameObj = nameObj.copyWith(text: 'Alexander Hamilton');

    // C. Modify Contact: Change email
    final contactObj = textObjects.firstWhere(
      (o) => o.text.contains('john.doe@example.com'),
      orElse: () => textObjects[1],
    );
    final modifiedContactObj = contactObj.copyWith(
      text: 'alexander.hamilton@treasury.gov | (555) 987-6543 | New York, NY',
    );

    // D. Insert New Experience Entry Text Object
    final newEntryObj = PdfTextContentObject(
      id: 'new_entry_01',
      pageIndex: 0,
      objectIndex: -1,
      bounds: const Rect.fromLTWH(50, 500, 400, 20),
      text: 'Principal Systems Architect — United States Treasury',
      fontName: 'Helvetica',
      fontSize: 12,
      isBold: true,
      fillColor: const Color(0xFF1976D2),
      isNew: true,
    );

    // E. Insert New Vector Separator Line
    final newLineObj = PdfPathContentObject(
      id: 'new_line_01',
      pageIndex: 0,
      objectIndex: -1,
      bounds: const Rect.fromLTWH(50, 480, 500, 2),
      shapeType: VectorShapeType.line,
      points: const [Offset(50, 480), Offset(550, 480)],
      hasStroke: true,
      hasFill: false,
      strokeColor: const Color(0xFF1976D2),
      strokeWidth: 2.5,
      isNew: true,
    );

    // F. Insert New Vector Rectangle Shape
    final newRectObj = PdfPathContentObject(
      id: 'new_rect_01',
      pageIndex: 0,
      objectIndex: -1,
      bounds: const Rect.fromLTWH(50, 450, 120, 24),
      shapeType: VectorShapeType.rectangle,
      points: const [Offset(50, 450), Offset(170, 474)],
      hasStroke: true,
      hasFill: true,
      strokeColor: const Color(0xFF00796B),
      fillColor: const Color(0xFFE0F2F1),
      strokeWidth: 1.5,
      isNew: true,
    );

    // Prepare modified list
    final modifiedList = List<PdfContentObject>.from(initialObjects);

    // Replace name
    final nameIdx = modifiedList.indexWhere((o) => o.id == nameObj.id);
    if (nameIdx != -1) modifiedList[nameIdx] = modifiedNameObj;

    // Replace contact
    final contactIdx = modifiedList.indexWhere((o) => o.id == contactObj.id);
    if (contactIdx != -1) modifiedList[contactIdx] = modifiedContactObj;

    // Add new elements
    modifiedList.add(newEntryObj);
    modifiedList.add(newLineObj);
    modifiedList.add(newRectObj);

    // G. Commit and save to new file
    final savedPath = await backend.commitModifications(
      sourcePath: originalResumePath,
      targetPath: editedResumePath,
      modifiedPagesObjects: {0: modifiedList},
      operations: [
        ModifyTextOperation(
          objectId: nameObj.id,
          pageIndex: 0,
          oldText: nameObj.text,
          newText: 'Alexander Hamilton',
        ),
        ModifyTextOperation(
          objectId: contactObj.id,
          pageIndex: 0,
          oldText: contactObj.text,
          newText: 'alexander.hamilton@treasury.gov',
        ),
        InsertObjectOperation(object: newEntryObj),
        InsertObjectOperation(object: newLineObj),
        InsertObjectOperation(object: newRectObj),
      ],
    );

    expect(File(savedPath).existsSync(), isTrue);
    expect(await File(savedPath).length(), greaterThan(500));

    // H. Technical Verification: Reopen and parse saved PDF
    final isIntact = await backend.verifyPdfIntegrity(filePath: savedPath);
    expect(isIntact, isTrue);

    // I. Extract modified objects from the saved PDF file
    final reloadedObjects = await backend.extractPageObjects(
      filePath: savedPath,
      pageIndex: 0,
    );
    expect(reloadedObjects, isNotEmpty);

    final reloadedTexts = reloadedObjects
        .whereType<PdfTextContentObject>()
        .toList();

    // Verify "Alexander Hamilton" is physically stored in the PDF
    final hasAlexander = reloadedTexts.any(
      (t) => t.text.contains('Alexander Hamilton'),
    );
    expect(
      hasAlexander,
      isTrue,
      reason: 'Saved PDF must contain modified Alexander Hamilton text',
    );

    // Verify updated email is physically stored in the PDF
    final hasGovEmail = reloadedTexts.any(
      (t) => t.text.contains('alexander.hamilton@treasury.gov'),
    );
    expect(
      hasGovEmail,
      isTrue,
      reason: 'Saved PDF must contain updated treasury email',
    );

    // Verify newly inserted native text entry is physically stored in the PDF
    final hasPrincipal = reloadedTexts.any(
      (t) => t.text.contains('Principal Systems Architect'),
    );
    expect(
      hasPrincipal,
      isTrue,
      reason: 'Saved PDF must contain newly inserted experience entry',
    );

    // Verify vector path objects exist
    final reloadedPaths = reloadedObjects
        .whereType<PdfPathContentObject>()
        .toList();
    expect(
      reloadedPaths.length,
      greaterThanOrEqualTo(2),
      reason: 'Saved PDF must contain new vector shapes',
    );

    // Verify original file was preserved unchanged
    final originalBytes = await File(originalResumePath).readAsBytes();
    final originalDoc = sf.PdfDocument(inputBytes: originalBytes);
    final originalText = sf.PdfTextExtractor(originalDoc).extractText();
    originalDoc.dispose();

    expect(
      originalText,
      contains('Johnathan Doe'),
      reason:
          'Original PDF file must never be damaged or overwritten unexpectedly',
    );
    expect(
      originalText,
      isNot(contains('Alexander Hamilton')),
      reason: 'Original PDF must remain untouched',
    );
  });
}
