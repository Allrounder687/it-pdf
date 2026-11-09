import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Generates a feature-rich, authentic PDF fixture for forensic integration testing.
/// Includes vector graphics, embedded fonts, AcroForms, bookmarks, page rotations,
/// hyperlinks, and mixed page dimensions.
class PdfTestFixtures {
  static Future<File> createComplexForensicPdfFixture({
    required String targetPath,
  }) async {
    final doc = sf.PdfDocument();

    // 1. Document Metadata (ISO 32000-1)
    doc.documentInformation.title = 'IT PDF Forensic Test Suite';
    doc.documentInformation.author = 'IT PDF QA Verification Core';
    doc.documentInformation.subject = 'Comprehensive Structural Audit Fixture';
    doc.documentInformation.keywords =
        'forensics, acroforms, vectors, bookmarks';

    // Page 1: Standard A4 Portrait (595.28 x 841.89 pt) - Vector graphics & text
    final page1 = doc.pages.add();
    final fontTitle = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      18,
      style: sf.PdfFontStyle.bold,
    );
    final fontBody = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);

    page1.graphics.drawString(
      'Page 1: Forensic Baseline & Vector Graphics',
      fontTitle,
      brush: sf.PdfSolidBrush(sf.PdfColor(15, 23, 42)),
      bounds: const Rect.fromLTWH(40, 40, 500, 30),
    );

    page1.graphics.drawString(
      'This page validates vector rendering, embedded fonts, and structural semantics.',
      fontBody,
      brush: sf.PdfSolidBrush(sf.PdfColor(71, 85, 105)),
      bounds: const Rect.fromLTWH(40, 80, 500, 20),
    );

    // Vector drawing: Rectangle, Bezier curve, line, and ellipse
    final pen = sf.PdfPen(sf.PdfColor(37, 99, 235), width: 2);
    page1.graphics.drawRectangle(
      pen: pen,
      bounds: const Rect.fromLTWH(40, 120, 200, 100),
    );
    page1.graphics.drawEllipse(
      const Rect.fromLTWH(260, 120, 120, 100),
      pen: sf.PdfPen(sf.PdfColor(16, 185, 129), width: 2),
      brush: sf.PdfSolidBrush(sf.PdfColor(209, 250, 229)),
    );
    page1.graphics.drawLine(pen, const Offset(40, 240), const Offset(500, 240));

    // Page 2: Letter Landscape (792.0 x 612.0 pt) - Interactive AcroForms
    doc.pageSettings.size = sf.PdfPageSize.letter;
    doc.pageSettings.orientation = sf.PdfPageOrientation.landscape;
    final page2 = doc.pages.add();

    page2.graphics.drawString(
      'Page 2: Interactive AcroForm Fields',
      fontTitle,
      brush: sf.PdfSolidBrush(sf.PdfColor(15, 23, 42)),
      bounds: const Rect.fromLTWH(40, 40, 600, 30),
    );

    // AcroForm: Text box field
    final fullNameField = sf.PdfTextBoxField(
      page2,
      'full_name',
      const Rect.fromLTWH(40, 90, 250, 25),
      text: 'Dr. Forensic Auditor',
    );
    doc.form.fields.add(fullNameField);

    // AcroForm: Email field
    final emailField = sf.PdfTextBoxField(
      page2,
      'email_address',
      const Rect.fromLTWH(40, 130, 250, 25),
      text: 'auditor@itpdf.test',
    );
    doc.form.fields.add(emailField);

    // AcroForm: Check box field
    final optInCheck = sf.PdfCheckBoxField(
      page2,
      'opt_in_notifications',
      const Rect.fromLTWH(40, 175, 20, 20),
      isChecked: true,
    );
    doc.form.fields.add(optInCheck);

    // AcroForm: Combo box field
    final comboField = sf.PdfComboBoxField(
      page2,
      'region_selector',
      const Rect.fromLTWH(40, 215, 200, 25),
    );
    comboField.items.add(sf.PdfListFieldItem('North America', 'NA'));
    comboField.items.add(sf.PdfListFieldItem('Europe', 'EU'));
    comboField.items.add(sf.PdfListFieldItem('Asia Pacific', 'APAC'));
    comboField.selectedIndex = 1;
    doc.form.fields.add(comboField);

    // Page 3: Rotated Page (90 degrees clockwise) - Hyperlinks & Annotations
    doc.pageSettings.size = sf.PdfPageSize.a4;
    doc.pageSettings.orientation = sf.PdfPageOrientation.portrait;
    final page3 = doc.pages.add();
    page3.rotation = sf.PdfPageRotateAngle.rotateAngle90;

    page3.graphics.drawString(
      'Page 3: Rotated Page (90 deg) & Document Links',
      fontTitle,
      brush: sf.PdfSolidBrush(sf.PdfColor(15, 23, 42)),
      bounds: const Rect.fromLTWH(40, 40, 500, 30),
    );

    // Web Hyperlink URI Annotation
    const linkRect = Rect.fromLTWH(40, 90, 250, 30);
    final link = sf.PdfUriAnnotation(
      bounds: linkRect,
      uri: 'https://github.com/Allrounder687/it-pdf',
    );
    link.text = 'IT PDF Source Repository';
    page3.annotations.add(link);

    // Document Bookmarks (Outlines)
    final bookmark1 = doc.bookmarks.add('1. Vector Graphics & Metadata');
    bookmark1.destination = sf.PdfDestination(page1, const Offset(0, 0));

    final bookmark2 = doc.bookmarks.add('2. Interactive AcroForms');
    bookmark2.destination = sf.PdfDestination(page2, const Offset(0, 0));

    final bookmark3 = doc.bookmarks.add('3. Rotated Page (90°) & Links');
    bookmark3.destination = sf.PdfDestination(page3, const Offset(0, 0));

    final subBookmark = bookmark3.add('3.1 Repository Hyperlink');
    subBookmark.destination = sf.PdfDestination(page3, const Offset(40, 90));

    // Save and flush to file
    final bytes = doc.saveSync();
    doc.dispose();

    final targetFile = File(targetPath);
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile;
  }
}
